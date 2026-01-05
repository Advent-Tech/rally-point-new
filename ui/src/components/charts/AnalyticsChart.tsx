import React from 'react';
import { View, Text, StyleSheet, Dimensions, Platform } from 'react-native';

const { width } = Dimensions.get('window');

import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../../constants/Colors';

// Simple chart implementation without external dependencies
const SimpleChart: React.FC<{
  data: number[];
  labels: string[];
  height: number;
  color: string;
  type: 'line' | 'bar';
}> = ({ data, labels, height, color, type }) => {
  const maxValue = Math.max(...data);
  const chartWidth = width - 80;
  const chartHeight = height - 60;

  return (
    <View style={[styles.simpleChart, { height }]}>
      <View style={styles.chartArea}>
        {type === 'bar' ? (
          <View style={styles.barContainer}>
            {data.map((value, index) => (
              <View key={index} style={styles.barWrapper}>
                <View
                  style={[
                    styles.bar,
                    {
                      height: (value / maxValue) * chartHeight,
                      backgroundColor: color,
                    },
                  ]}
                />
                <Text style={styles.barLabel}>{labels[index]}</Text>
              </View>
            ))}
          </View>
        ) : (
          <View style={styles.lineContainer}>
            {data.map((value, index) => (
              <View key={index} style={styles.linePoint}>
                <View
                  style={[
                    styles.point,
                    {
                      bottom: (value / maxValue) * chartHeight,
                      backgroundColor: color,
                    },
                  ]}
                />
                {index < data.length - 1 && (
                  <View
                    style={[
                      styles.line,
                      {
                        backgroundColor: color,
                        height: Math.abs(
                          ((data[index + 1] - value) / maxValue) * chartHeight
                        ),
                      },
                    ]}
                  />
                )}
              </View>
            ))}
            <View style={styles.lineLabels}>
              {labels.map((label, index) => (
                <Text key={index} style={styles.lineLabel}>
                  {label}
                </Text>
              ))}
            </View>
          </View>
        )}
      </View>
    </View>
  );
};

interface AnalyticsLineChartProps {
  title: string;
  data: {
    labels: string[];
    datasets: Array<{
      data: number[];
      color?: (opacity: number) => string;
      strokeWidth?: number;
    }>;
  };
  suffix?: string;
  height?: number;
}

export const AnalyticsLineChart: React.FC<AnalyticsLineChartProps> = ({
  title,
  data,
  suffix = '',
  height = 220,
}) => {
  const chartData = data.datasets[0]?.data || [];
  const labels = data.labels || [];

  return (
    <View style={styles.chartContainer}>
      <Text style={styles.chartTitle}>{title}</Text>
      <SimpleChart
        data={chartData}
        labels={labels}
        height={height - 60}
        color={COLORS.secondary}
        type="line"
      />
      <View style={styles.chartLegend}>
        <Text style={styles.legendText}>
          Max: {Math.max(...chartData).toFixed(1)}{suffix}
        </Text>
        <Text style={styles.legendText}>
          Avg: {(chartData.reduce((a, b) => a + b, 0) / chartData.length).toFixed(1)}{suffix}
        </Text>
      </View>
    </View>
  );
};

interface AnalyticsBarChartProps {
  title: string;
  data: {
    labels: string[];
    datasets: Array<{
      data: number[];
    }>;
  };
  suffix?: string;
  height?: number;
}

export const AnalyticsBarChart: React.FC<AnalyticsBarChartProps> = ({
  title,
  data,
  suffix = '',
  height = 220,
}) => {
  const chartData = data.datasets[0]?.data || [];
  const labels = data.labels || [];

  return (
    <View style={styles.chartContainer}>
      <Text style={styles.chartTitle}>{title}</Text>
      <SimpleChart
        data={chartData}
        labels={labels}
        height={height - 60}
        color={COLORS.primary}
        type="bar"
      />
      <View style={styles.chartLegend}>
        <Text style={styles.legendText}>
          Total: {chartData.reduce((a, b) => a + b, 0)}{suffix}
        </Text>
        <Text style={styles.legendText}>
          Peak: {Math.max(...chartData)}{suffix}
        </Text>
      </View>
    </View>
  );
};

interface AnalyticsPieChartProps {
  title: string;
  data: Array<{
    name: string;
    population: number;
    color: string;
    legendFontColor: string;
    legendFontSize: number;
  }>;
  height?: number;
}

export const AnalyticsPieChart: React.FC<AnalyticsPieChartProps> = ({
  title,
  data,
  height = 220,
}) => {
  const total = data.reduce((sum, item) => sum + item.population, 0);

  return (
    <View style={styles.chartContainer}>
      <Text style={styles.chartTitle}>{title}</Text>
      <View style={styles.pieChartContainer}>
        {data.map((item, index) => {
          const percentage = (item.population / total) * 100;
          return (
            <View key={index} style={styles.pieItem}>
              <View
                style={[
                  styles.pieIndicator,
                  { backgroundColor: item.color },
                ]}
              />
              <Text style={styles.pieLabel}>{item.name}</Text>
              <Text style={styles.pieValue}>{percentage.toFixed(1)}%</Text>
            </View>
          );
        })}
      </View>
    </View>
  );
};

interface AnalyticsProgressChartProps {
  title: string;
  data: {
    labels: string[];
    data: number[];
  };
  height?: number;
}

export const AnalyticsProgressChart: React.FC<AnalyticsProgressChartProps> = ({
  title,
  data,
  height = 220,
}) => {
  return (
    <View style={styles.chartContainer}>
      <Text style={styles.chartTitle}>{title}</Text>
      <View style={styles.progressChartContainer}>
        {data.labels.map((label, index) => {
          const progress = data.data[index] * 100;
          return (
            <View key={index} style={styles.progressItem}>
              <Text style={styles.progressLabel}>{label}</Text>
              <View style={styles.progressBarContainer}>
                <View style={styles.progressBarBg}>
                  <View
                    style={[
                      styles.progressBarFill,
                      {
                        width: `${progress}%`,
                        backgroundColor: COLORS.secondary,
                      },
                    ]}
                  />
                </View>
                <Text style={styles.progressText}>{progress.toFixed(1)}%</Text>
              </View>
            </View>
          );
        })}
      </View>
    </View>
  );
};

interface MetricCardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  icon?: string;
  color?: string;
  trend?: {
    value: number;
    isPositive: boolean;
  };
}

export const MetricCard: React.FC<MetricCardProps> = ({
  title,
  value,
  subtitle,
  icon,
  color = COLORS.primary,
  trend,
}) => {
  // Web-optimized value formatting to prevent rapid re-renders
  const formattedValue = React.useMemo(() => {
    if (typeof value === 'number') {
      return Platform.OS === 'web' 
        ? Math.round(value * 10) / 10 // Round to 1 decimal on web
        : value;
    }
    return value;
  }, [value]);

  return (
    <View style={[
      styles.metricCard, 
      Platform.OS === 'web' 
        ? { borderLeftWidth: 4, borderLeftColor: color }
        : { borderLeftColor: color }
    ]}>
      <View style={styles.metricHeader}>
        <Text style={styles.metricTitle}>{title}</Text>
        {icon && <Text style={styles.metricIcon}>{icon}</Text>}
      </View>
      
      <Text style={[styles.metricValue, { color }]}>{formattedValue}</Text>
      
      {subtitle && (
        <Text style={styles.metricSubtitle}>{subtitle}</Text>
      )}
      
      {trend && (
        <View style={styles.trendContainer}>
          <Text style={[
            styles.trendText,
            { color: trend.isPositive ? COLORS.success : COLORS.error }
          ]}>
            {trend.isPositive ? '↗' : '↘'} {Platform.OS === 'web' 
              ? Math.round(Math.abs(trend.value))
              : Math.abs(trend.value)
            }%
          </Text>
        </View>
      )}
    </View>
  );
};

interface ProgressBarProps {
  title: string;
  progress: number; // 0-100
  color?: string;
  showPercentage?: boolean;
}

export const ProgressBar: React.FC<ProgressBarProps> = ({
  title,
  progress,
  color = COLORS.secondary,
  showPercentage = true,
}) => {
  // Web-optimized progress calculation to prevent vibrating
  const safeProgress = Math.min(Math.max(progress || 0, 0), 100);
  const roundedProgress = Platform.OS === 'web' 
    ? Math.round(safeProgress) // Round to whole numbers on web
    : safeProgress;

  return (
    <View style={styles.progressContainer}>
      <View style={styles.progressHeader}>
        <Text style={styles.progressTitle}>{title}</Text>
        {showPercentage && (
          <Text style={styles.progressPercentage}>
            {Platform.OS === 'web' 
              ? `${Math.round(safeProgress)}%` // Rounded percentage for web
              : `${safeProgress.toFixed(1)}%`
            }
          </Text>
        )}
      </View>
      
      <View style={styles.progressBarBackground}>
        <View 
          style={[
            styles.progressBarFill,
            Platform.OS === 'web' 
              ? {
                  // Use fixed width calculation for web to prevent jitter
                  width: Math.round((roundedProgress / 100) * 200), // Fixed 200px width
                  backgroundColor: color 
                }
              : { 
                  width: `${roundedProgress}%`,
                  backgroundColor: color 
                }
          ]} 
        />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  chartContainer: {
    backgroundColor: COLORS.white,
    borderRadius: 16,
    padding: 16,
    marginVertical: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  chartTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: COLORS.primary,
    marginBottom: 12,
    textAlign: 'center',
  },
  chart: {
    borderRadius: 16,
  },
  metricCard: {
    backgroundColor: COLORS.white,
    borderRadius: 12,
    padding: 16,
    marginVertical: 6,
    borderLeftWidth: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  metricHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  metricTitle: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.medium,
  },
  metricIcon: {
    fontSize: 20,
  },
  metricValue: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  metricSubtitle: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
  },
  trendContainer: {
    marginTop: 8,
  },
  trendText: {
    fontSize: 12,
    fontWeight: '600',
  },
  progressContainer: {
    backgroundColor: COLORS.white,
    borderRadius: 12,
    padding: 16,
    marginVertical: 6,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  progressHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  progressTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.primary,
  },
  progressPercentage: {
    fontSize: 14,
    fontWeight: 'bold',
    color: COLORS.secondary,
  },
  progressBarBackground: {
    height: 8,
    backgroundColor: COLORS.background.disabled,
    borderRadius: RADIUS.sm,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    borderRadius: 4,
  },
  // Simple Chart Styles
  simpleChart: {
    backgroundColor: COLORS.white,
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  chartArea: {
    flex: 1,
    width: '100%',
  },
  barContainer: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-around',
    height: '100%',
    paddingBottom: 20,
  },
  barWrapper: {
    alignItems: 'center',
    flex: 1,
  },
  bar: {
    width: 20,
    borderRadius: 4,
    marginBottom: 8,
  },
  barLabel: {
    fontSize: 10,
    color: COLORS.darkGray,
    textAlign: 'center',
  },
  lineContainer: {
    position: 'relative',
    height: '100%',
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-around',
  },
  linePoint: {
    position: 'relative',
    alignItems: 'center',
  },
  point: {
    width: 8,
    height: 8,
    borderRadius: 4,
    position: 'absolute',
  },
  line: {
    width: 2,
    position: 'absolute',
    left: 3,
  },
  lineLabels: {
    position: 'absolute',
    bottom: -20,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  lineLabel: {
    fontSize: 10,
    color: COLORS.darkGray,
    textAlign: 'center',
  },
  chartLegend: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: COLORS.lightGray,
  },
  legendText: {
    fontSize: 12,
    color: COLORS.darkGray,
    fontWeight: '500',
  },
  pieChartContainer: {
    paddingVertical: 20,
  },
  pieItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 8,
  },
  pieIndicator: {
    width: 16,
    height: 16,
    borderRadius: 8,
    marginRight: 12,
  },
  pieLabel: {
    flex: 1,
    fontSize: 14,
    color: COLORS.primary,
  },
  pieValue: {
    fontSize: 14,
    fontWeight: 'bold',
    color: COLORS.secondary,
  },
  progressChartContainer: {
    paddingVertical: 20,
  },
  progressItem: {
    marginVertical: 12,
  },
  progressLabel: {
    fontSize: 14,
    color: COLORS.primary,
    marginBottom: 8,
    fontWeight: '500',
  },
  progressBarContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  progressBarBg: {
    flex: 1,
    height: 8,
    backgroundColor: COLORS.lightGray,
    borderRadius: 4,
    marginRight: 12,
  },
  progressText: {
    fontSize: 12,
    color: COLORS.secondary,
    fontWeight: 'bold',
    minWidth: 40,
  },
});
