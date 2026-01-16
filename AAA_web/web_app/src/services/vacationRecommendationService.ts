import { API_BASE_URL } from '../utils/apiConfig';
import { createLogger } from '../utils/logger';
import type {
    VacationRecommendationResponse,
    LeavesData,
    WeekdayCountsData,
    ConsecutivePeriod,
} from '../types/leave';

const logger = createLogger('VacationRecommendationService');

/**
 * AI 휴가 추천을 위한 마크다운 콘텐츠 파서
 */
class VacationContentParser {
    /**
     * 마크다운 텍스트에서 월별 분포 데이터 추출
     */
    static parseMonthlyDistribution(markdown: string, yearHint?: number): Record<string, number> {
        const distribution: Record<string, number> = {};
        const fullDateRegex = /•\s+(\d{4}-\d{2}):\s+(\d+(?:\.\d+)?)일/g;
        let match;
        while ((match = fullDateRegex.exec(markdown)) !== null) {
            distribution[match[1]] = parseFloat(match[2]);
        }

        const year = yearHint ?? new Date().getFullYear();
        const monthOnlyRegex = /(\d{1,2})월\s*[:：]\s*(\d+(?:\.\d+)?)일/g;
        while ((match = monthOnlyRegex.exec(markdown)) !== null) {
            const month = match[1].padStart(2, '0');
            const days = parseFloat(match[2]);
            distribution[`${year}-${month}`] = days;
        }

        return distribution;
    }

    /**
     * 마크다운 텍스트에서 연속 휴가 기간 추출
     */
    static parseConsecutivePeriods(markdown: string): ConsecutivePeriod[] {
        const periods: ConsecutivePeriod[] = [];
        const simpleRegex = /•\s+(\d{4}-\d{2}-\d{2})\s+~\s+(\d{4}-\d{2}-\d{2}):\s+(\d+)일/g;
        let match;
        while ((match = simpleRegex.exec(markdown)) !== null) {
            const lineEndIndex = markdown.indexOf('\n', match.index);
            const description = lineEndIndex !== -1
                ? markdown.substring(match.index + match[0].length, lineEndIndex).trim()
                : '';

            periods.push({
                startDate: match[1],
                endDate: match[2],
                days: parseInt(match[3], 10),
                description: description.replace(/^[:\s-]+/, ''),
            });
        }

        const detailedRegex = /(\d{4}-\d{2}-\d{2})\s*~\s*(\d{4}-\d{2}-\d{2})\s*\((\d+)일\):\s*([^\n]+)/g;
        while ((match = detailedRegex.exec(markdown)) !== null) {
            const startDate = match[1];
            const endDate = match[2];
            const alreadyExists = periods.some((period) => period.startDate === startDate && period.endDate === endDate);
            if (alreadyExists) continue;

            periods.push({
                startDate,
                endDate,
                days: parseInt(match[3], 10),
                description: match[4].trim(),
            });
        }

        return periods;
    }

    /**
     * 마크다운 내부에 포함된 JSON 데이터 추출
     */
    static parseJsonFromMarkdown(markdown: string): any {
        try {
            const jsonMatch = markdown.match(/```json\s*([\s\S]*?)\s*```/);
            if (jsonMatch && jsonMatch[1]) {
                const cleaned = jsonMatch[1].replace(/^#.*$/gm, '').trim();
                return JSON.parse(cleaned);
            }
            const startIndex = markdown.indexOf('{');
            const endIndex = markdown.lastIndexOf('}');
            if (startIndex !== -1 && endIndex !== -1 && endIndex > startIndex) {
                const jsonString = markdown.substring(startIndex, endIndex + 1);
                const cleaned = jsonString.replace(/^#.*$/gm, '').trim();
                return JSON.parse(cleaned);
            }
        } catch (e) {
            return null;
        }
        return null;
    }

    static normalizeLeavesData(leaves: Record<string, any> | undefined, yearHint?: number): Record<string, number> {
        const normalized: Record<string, number> = {};
        if (!leaves) {
            return normalized;
        }

        const isYearKey = (key: string) => /^\d{4}$/.test(key);
        const isYearMonthKey = (key: string) => /^\d{4}-\d{2}$/.test(key);
        const fallbackYear = yearHint ?? new Date().getFullYear();

        Object.entries(leaves).forEach(([key, value]) => {
            if (isYearMonthKey(key) && typeof value === 'number') {
                normalized[key] = value;
                return;
            }

            if (isYearKey(key) && value && typeof value === 'object') {
                Object.entries(value as Record<string, unknown>).forEach(([monthKey, days]) => {
                    const month = monthKey.padStart(2, '0');
                    const numericDays = typeof days === 'number' ? days : Number(days);
                    if (!Number.isNaN(numericDays)) {
                        normalized[`${key}-${month}`] = numericDays;
                    }
                });
                return;
            }

            if (typeof value === 'number') {
                const month = key.padStart(2, '0');
                normalized[`${fallbackYear}-${month}`] = value;
            }
        });

        return normalized;
    }
}

/**
 * AI 휴가 추천 요청 (SSE 스트리밍)
 */
export async function* fetchVacationRecommendation(
    userId: string,
    year: number
): AsyncGenerator<VacationRecommendationResponse> {
    const url = `${API_BASE_URL}/leave/user/annualPlans`;

    logger.dev('AI 휴가 추천 요청 시작:', { userId, year, url });

    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ user_id: userId }),
        });

        if (!response.ok) {
            throw new Error(`API 요청 실패 (HTTP ${response.status})`);
        }

        const reader = response.body?.getReader();
        if (!reader) {
            throw new Error('응답 바디를 읽을 수 없습니다.');
        }

        const decoder = new TextDecoder();
        let currentEventType = '';
    let reasoningBuffer = '';
    let markdownBuffer = '';
    let isAfterMarker = false;

    let leavesData: LeavesData | undefined;
        let weekdayCountsData: WeekdayCountsData | undefined;
        let holidayAdjacentUsageRate: number | undefined;
        let holidayAdjacentDays: number | undefined;
        let totalLeaveDays: number | undefined;

        let streamError: unknown = null;

        while (true) {
            let readResult;
            try {
                readResult = await reader.read();
            } catch (error) {
                streamError = error;
                logger.warn('AI 휴가 추천 스트림 읽기 오류 (부분 데이터로 완료 처리):', error);
                break;
            }
            const { done, value } = readResult;
            if (done) break;

            const chunk = decoder.decode(value, { stream: true });
            const lines = chunk.split('\n');

            for (const line of lines) {
                if (line.trim() === '') continue;

                if (line.startsWith('event: ')) {
                    currentEventType = line.substring(7).trim();
                    continue;
                }

                if (line.startsWith('data: ')) {
                    const data = line.substring(6).trim();
                    if (!data) continue;

            if (currentEventType === 'reasoning') {
                if (data.includes('📊')) {
                    isAfterMarker = true;
                }

                if (!isAfterMarker) {
                    let isJsonData = false;
                    if (data.includes('{')) {
                        const startIndex = data.indexOf('{');
                        const endIndex = data.lastIndexOf('}');
                        if (startIndex !== -1 && endIndex !== -1 && endIndex > startIndex) {
                            const jsonString = data.substring(startIndex, endIndex + 1);
                            try {
                                const cleaned = jsonString.replace(/^#.*$/gm, '').trim();
                                const json = JSON.parse(cleaned);
                                if (json.leaves) {
                                    leavesData = {
                                        monthlyUsage: VacationContentParser.normalizeLeavesData(json.leaves, year),
                                    };
                                    isJsonData = true;
                                } else if (json.weekday_counts) {
                                    weekdayCountsData = { counts: json.weekday_counts };
                                    isJsonData = true;
                                }
                            } catch (e) {
                                if (data.includes('weekday_counts') || data.includes('"leaves"')) {
                                    isJsonData = true;
                                }
                            }
                        }
                    } else if (data.includes('weekday_counts') || data.includes('"leaves"')) {
                        isJsonData = true;
                    }

                    if (!isJsonData) {
                        reasoningBuffer += data + '\n';
                    }

                            yield {
                                reasoningContents: reasoningBuffer,
                                finalResponseContents: '',
                                recommendedDates: [],
                                monthlyDistribution: {},
                                consecutivePeriods: [],
                                isComplete: false,
                                streamingProgress: 0.4,
                                leavesData,
                                weekdayCountsData,
                                isAfterAnalysisMarker: false,
                                markdownBuffer: '',
                            };

                        } else {
                            markdownBuffer += data;
                            yield {
                                reasoningContents: reasoningBuffer,
                                finalResponseContents: '',
                                recommendedDates: [],
                                monthlyDistribution: {},
                                consecutivePeriods: [],
                                isComplete: false,
                                streamingProgress: 0.7,
                                leavesData,
                                weekdayCountsData,
                                isAfterAnalysisMarker: true,
                                markdownBuffer: markdownBuffer,
                            };
                        }
                    } else if (currentEventType === 'final') {
                        markdownBuffer += data;
                        yield {
                            reasoningContents: reasoningBuffer,
                            finalResponseContents: markdownBuffer,
                            recommendedDates: [],
                            monthlyDistribution: {},
                            consecutivePeriods: [],
                            isComplete: false,
                            streamingProgress: 0.9,
                            leavesData,
                            weekdayCountsData,
                            isAfterAnalysisMarker: true,
                            markdownBuffer: markdownBuffer,
                        };
                    }
                }
            }
        }

        if (streamError && !reasoningBuffer && !markdownBuffer && !leavesData && !weekdayCountsData) {
            throw streamError;
        }

        const monthlyDistribution = VacationContentParser.parseMonthlyDistribution(markdownBuffer, year);
        const consecutivePeriods = VacationContentParser.parseConsecutivePeriods(markdownBuffer);
        const jsonData = VacationContentParser.parseJsonFromMarkdown(markdownBuffer);

        if (jsonData) {
            if (!leavesData && jsonData.leaves) {
                leavesData = {
                    monthlyUsage: VacationContentParser.normalizeLeavesData(jsonData.leaves, year),
                };
            }
            if (!weekdayCountsData && jsonData.weekday_counts) {
                weekdayCountsData = { counts: jsonData.weekday_counts };
            }
            if (Object.prototype.hasOwnProperty.call(jsonData, 'holiday_adjacent_usage_rate')) {
                holidayAdjacentUsageRate = Number(jsonData.holiday_adjacent_usage_rate);
            }
            if (Object.prototype.hasOwnProperty.call(jsonData, 'holiday_adjacent_days')) {
                holidayAdjacentDays = Number(jsonData.holiday_adjacent_days);
            }
            if (Object.prototype.hasOwnProperty.call(jsonData, 'total_leave_days')) {
                totalLeaveDays = Number(jsonData.total_leave_days);
            }
        }

        const recommendedDates: string[] = [];
        const dateRegex = /\b(\d{4}-\d{2}-\d{2})\b/g;
        let dateMatch;
        while ((dateMatch = dateRegex.exec(markdownBuffer)) !== null) {
            if (!recommendedDates.includes(dateMatch[1])) {
                recommendedDates.push(dateMatch[1]);
            }
        }

        yield {
            reasoningContents: reasoningBuffer,
            finalResponseContents: markdownBuffer,
            recommendedDates,
            monthlyDistribution,
            consecutivePeriods,
            isComplete: true,
            streamingProgress: 1.0,
            leavesData,
            weekdayCountsData,
            holidayAdjacentUsageRate,
            holidayAdjacentDays,
            totalLeaveDays,
            isAfterAnalysisMarker: true,
            markdownBuffer,
        };

    } catch (error: any) {
        logger.error('AI 휴가 추천 스트리밍 에러:', error);
        throw error;
    }
}
