import type {
  ConsecutivePeriod,
  LeavesData,
  WeekdayCountsData,
} from '../types/leave';

export interface LeaveAnalyzeParsedData {
  leavesData?: LeavesData;
  weekdayCountsData?: WeekdayCountsData;
  holidayAdjacentUsageRate?: number;
  holidayAdjacentDays?: number;
  totalLeaveDays?: number;
  monthlyDistribution: Record<string, number>;
  consecutivePeriods: ConsecutivePeriod[];
  recommendedDates: string[];
}

function findMatchingBrace(content: string, startIndex: number) {
  let depth = 0;
  for (let i = startIndex; i < content.length; i += 1) {
    const char = content[i];
    if (char === '{') {
      depth += 1;
    } else if (char === '}') {
      depth -= 1;
      if (depth === 0) {
        return content.slice(startIndex, i + 1);
      }
    }
  }
  return null;
}

function extractJsonByKey(content: string, key: string) {
  const keyIndex = content.indexOf(`"${key}"`);
  if (keyIndex === -1) return null;
  const braceStart = content.lastIndexOf('{', keyIndex);
  if (braceStart === -1) return null;
  return findMatchingBrace(content, braceStart);
}

function parseJsonString(raw: string) {
  const cleaned = raw.replace(/^#.*$/gm, '').trim();
  return JSON.parse(cleaned);
}

function parseJsonFromFence(content: string) {
  const jsonMatch = content.match(/```json\s*([\s\S]*?)\s*```/);
  if (!jsonMatch || !jsonMatch[1]) return null;
  try {
    return parseJsonString(jsonMatch[1]);
  } catch (error) {
    return null;
  }
}

function parseJsonFromContent(content: string) {
  const fenceJson = parseJsonFromFence(content);
  if (fenceJson) return fenceJson;
  const startIndex = content.indexOf('{');
  const endIndex = content.lastIndexOf('}');
  if (startIndex !== -1 && endIndex !== -1 && endIndex > startIndex) {
    const raw = content.slice(startIndex, endIndex + 1);
    try {
      return parseJsonString(raw);
    } catch (error) {
      return null;
    }
  }
  return null;
}

function normalizeLeavesData(leaves: Record<string, any> | undefined, yearHint?: number): Record<string, number> {
  const normalized: Record<string, number> = {};
  if (!leaves) return normalized;

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

function parseMonthlyDistribution(content: string, yearHint?: number): Record<string, number> {
  const distribution: Record<string, number> = {};
  const fullDateRegex = /•\s+(\d{4}-\d{2}):\s+(\d+(?:\.\d+)?)일/g;
  let match;
  while ((match = fullDateRegex.exec(content)) !== null) {
    distribution[match[1]] = parseFloat(match[2]);
  }

  const year = yearHint ?? new Date().getFullYear();
  const monthOnlyRegex = /(\d{1,2})월\s*[:：]\s*(\d+(?:\.\d+)?)일/g;
  while ((match = monthOnlyRegex.exec(content)) !== null) {
    const month = match[1].padStart(2, '0');
    distribution[`${year}-${month}`] = parseFloat(match[2]);
  }

  return distribution;
}

function parseConsecutivePeriods(content: string): ConsecutivePeriod[] {
  const periods: ConsecutivePeriod[] = [];
  const simpleRegex = /•\s+(\d{4}-\d{2}-\d{2})\s+~\s+(\d{4}-\d{2}-\d{2}):\s+(\d+)일/g;
  let match;
  while ((match = simpleRegex.exec(content)) !== null) {
    const lineEndIndex = content.indexOf('\n', match.index);
    const description = lineEndIndex !== -1
      ? content.substring(match.index + match[0].length, lineEndIndex).trim()
      : '';

    periods.push({
      startDate: match[1],
      endDate: match[2],
      days: parseInt(match[3], 10),
      description: description.replace(/^[:\s-]+/, ''),
    });
  }

  const detailedRegex = /(\d{4}-\d{2}-\d{2})\s*~\s*(\d{4}-\d{2}-\d{2})\s*\((\d+)일\):\s*([^\n]+)/g;
  while ((match = detailedRegex.exec(content)) !== null) {
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

function parseRecommendedDates(content: string) {
  const dates: string[] = [];
  const dateRegex = /\b(\d{4}-\d{2}-\d{2})\b/g;
  let match;
  while ((match = dateRegex.exec(content)) !== null) {
    if (!dates.includes(match[1])) {
      dates.push(match[1]);
    }
  }
  return dates;
}

export function parseLeaveAnalyzeMessage(content: string, yearHint?: number): LeaveAnalyzeParsedData {
  const parsed: LeaveAnalyzeParsedData = {
    monthlyDistribution: {},
    consecutivePeriods: [],
    recommendedDates: [],
  };

  const jsonData = parseJsonFromContent(content);
  if (jsonData) {
    if (jsonData.leaves) {
      parsed.leavesData = { monthlyUsage: normalizeLeavesData(jsonData.leaves, yearHint) };
    }
    if (jsonData.weekday_counts) {
      parsed.weekdayCountsData = { counts: jsonData.weekday_counts };
    }
    if (Object.prototype.hasOwnProperty.call(jsonData, 'holiday_adjacent_usage_rate')) {
      parsed.holidayAdjacentUsageRate = Number(jsonData.holiday_adjacent_usage_rate);
    }
    if (Object.prototype.hasOwnProperty.call(jsonData, 'holiday_adjacent_days')) {
      parsed.holidayAdjacentDays = Number(jsonData.holiday_adjacent_days);
    }
    if (Object.prototype.hasOwnProperty.call(jsonData, 'total_leave_days')) {
      parsed.totalLeaveDays = Number(jsonData.total_leave_days);
    }
  }

  if (!parsed.leavesData) {
    const leavesJson = extractJsonByKey(content, 'leaves');
    if (leavesJson) {
      try {
        const json = parseJsonString(leavesJson);
        if (json.leaves) {
          parsed.leavesData = { monthlyUsage: normalizeLeavesData(json.leaves, yearHint) };
        }
      } catch (error) {
        // ignore
      }
    }
  }

  if (!parsed.weekdayCountsData) {
    const weekdayJson = extractJsonByKey(content, 'weekday_counts');
    if (weekdayJson) {
      try {
        const json = parseJsonString(weekdayJson);
        if (json.weekday_counts) {
          parsed.weekdayCountsData = { counts: json.weekday_counts };
        }
      } catch (error) {
        // ignore
      }
    }
  }

  if (parsed.holidayAdjacentUsageRate === undefined) {
    const match = content.match(/"holiday_adjacent_usage_rate"\s*:\s*([\d.]+)/);
    if (match) {
      parsed.holidayAdjacentUsageRate = Number(match[1]);
    }
  }

  parsed.monthlyDistribution = parseMonthlyDistribution(content, yearHint);
  parsed.consecutivePeriods = parseConsecutivePeriods(content);
  parsed.recommendedDates = parseRecommendedDates(content);

  return parsed;
}
