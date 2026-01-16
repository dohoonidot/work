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
    static parseMonthlyDistribution(markdown: string): Record<string, number> {
        const distribution: Record<string, number> = {};
        const regex = /•\s+(\d{4}-\d{2}):\s+(\d+)일/g;
        let match;
        while ((match = regex.exec(markdown)) !== null) {
            distribution[match[1]] = parseInt(match[2], 10);
        }
        return distribution;
    }

    /**
     * 마크다운 텍스트에서 연속 휴가 기간 추출
     */
    static parseConsecutivePeriods(markdown: string): ConsecutivePeriod[] {
        const periods: ConsecutivePeriod[] = [];
        const regex = /•\s+(\d{4}-\d{2}-\d{2})\s+~\s+(\d{4}-\d{2}-\d{2}):\s+(\d+)일/g;
        let match;
        while ((match = regex.exec(markdown)) !== null) {
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
        return periods;
    }

    /**
     * 마크다운 내부에 포함된 JSON 데이터 추출
     */
    static parseJsonFromMarkdown(markdown: string): any {
        try {
            const jsonMatch = markdown.match(/```json\s*([\s\S]*?)\s*```/);
            if (jsonMatch && jsonMatch[1]) {
                return JSON.parse(jsonMatch[1]);
            }
            return null;
        } catch (e) {
            return null;
        }
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

        while (true) {
            const { done, value } = await reader.read();
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
                                try {
                                    const startIndex = data.indexOf('{');
                                    const endIndex = data.lastIndexOf('}');
                                    if (startIndex !== -1 && endIndex !== -1 && endIndex > startIndex) {
                                        const jsonString = data.substring(startIndex, endIndex + 1);
                                        const json = JSON.parse(jsonString);

                                        if (json.leaves) {
                                            leavesData = { monthlyUsage: json.leaves };
                                            isJsonData = true;
                                        } else if (json.weekday_counts) {
                                            weekdayCountsData = { counts: json.weekday_counts };
                                            isJsonData = true;
                                        }
                                    }
                                } catch (e) {
                                    // ignore
                                }
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

        const monthlyDistribution = VacationContentParser.parseMonthlyDistribution(markdownBuffer);
        const consecutivePeriods = VacationContentParser.parseConsecutivePeriods(markdownBuffer);
        const jsonData = VacationContentParser.parseJsonFromMarkdown(markdownBuffer);

        if (jsonData) {
            if (jsonData.holiday_adjacent_usage_rate) {
                holidayAdjacentUsageRate = Number(jsonData.holiday_adjacent_usage_rate);
            }
            if (jsonData.holiday_adjacent_days) {
                holidayAdjacentDays = Number(jsonData.holiday_adjacent_days);
            }
            if (jsonData.total_leave_days) {
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
