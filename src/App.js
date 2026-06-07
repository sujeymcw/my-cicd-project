import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ActivityIndicator, ScrollView, SafeAreaView, TouchableOpacity } from 'react-native';
import { StatusBar } from 'expo-status-bar';

export default function App() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [refreshKey, setRefreshKey] = useState(0);
  
  // New Appearance State Additions
  const [isLightTheme, setIsLightTheme] = useState(false);
  const [lastSyncTime, setLastSyncTime] = useState('');

  useEffect(() => {
    // Poll the local Python API data bridge
    fetch('http://127.0.0.1:8000/api/metrics')
      .then((res) => res.json())
      .then((json) => {
        setData(json);
        setLoading(false);
        // Track precisely when the client successfully fetched structural telemetries
        const now = new Date();
        setLastSyncTime(now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }));
      })
      .catch((err) => {
        console.error("API Error: Make sure your Python backend is running!", err);
      });
  }, [refreshKey]);

  // Dynamic Theme Palette Resolver
  const theme = {
    containerBg: isLightTheme ? '#F7FAFC' : '#0A0E17',
    cardBg: isLightTheme ? '#FFFFFF' : 'rgba(26, 32, 44, 0.6)',
    cardBorder: isLightTheme ? '#E2E8F0' : 'rgba(255, 255, 255, 0.05)',
    primaryText: isLightTheme ? '#1A202C' : '#FFFFFF',
    secondaryText: isLightTheme ? '#4A5568' : '#718096',
    labelText: isLightTheme ? '#4A5568' : '#718096',
    valueText: isLightTheme ? '#2D3748' : '#E2E8F0',
    cardTitleText: isLightTheme ? '#2D3748' : '#EDF2F7',
    commitMsgText: isLightTheme ? '#718096' : '#4A5568',
    statusBar: isLightTheme ? 'dark' : 'light'
  };

  if (loading || !data) {
    return (
      <View style={[styles.center, { backgroundColor: theme.containerBg }]}>
        <ActivityIndicator size="large" color="#00E5FF" />
        <Text style={styles.loadingText}>Connecting to Cluster Control Plane...</Text>
      </View>
    );
  }

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: theme.containerBg }]}>
      <StatusBar style={theme.statusBar} />
      <ScrollView contentContainerStyle={styles.scrollContainer}>
        
        {/* Header Dashboard Title & Theme Switcher Configuration */}
        <View style={styles.header}>
          <View style={styles.headerTopRow}>
            <View>
              <Text style={[styles.mainTitle, { color: theme.primaryText }]}>🎛️ Control Plane</Text>
              <Text style={[styles.mainSubtitle, { color: theme.secondaryText }]}>Live DevOps Telemetry Engine</Text>
            </View>
            
            {/* Interactive Theme Appearance Selector Trigger */}
            <TouchableOpacity 
              style={[styles.themeToggleButton, { backgroundColor: isLightTheme ? '#2D3748' : '#EDF2F7' }]} 
              onPress={() => setIsLightTheme(!isLightTheme)}
            >
              <Text style={[styles.themeToggleText, { color: isLightTheme ? '#FFFFFF' : '#1A202C' }]}>
                {isLightTheme ? '🌙 Dark Mode' : '☀️ Light Mode'}
              </Text>
            </TouchableOpacity>
          </View>
          
          {/* Live Sync Confirmation Metrics Block */}
          <View style={styles.syncStatusRow}>
            <Text style={[styles.syncStatusLabel, { color: theme.secondaryText }]}>
              🟢 Telemetry Status: <Text style={{ fontWeight: '700', color: '#4CAF50' }}>CONNECTED</Text>
            </Text>
            {lastSyncTime ? (
              <Text style={[styles.syncTimeText, { color: theme.secondaryText }]}>
                Last Node Sync: {lastSyncTime}
              </Text>
            ) : null}
          </View>
        </View>

        {/* Dashboard Responsive Grid */}
        <View style={styles.grid}>
          
          {/* Card 1: Git Repository Data */}
          <View style={[styles.card, { backgroundColor: theme.cardBg, borderColor: theme.cardBorder }]}>
            <Text style={[styles.cardTitle, { color: theme.cardTitleText }]}>📁 Repository Hub</Text>
            <View style={styles.metricRow}>
              <Text style={[styles.label, { color: theme.labelText }]}>Source:</Text>
              <Text style={[styles.value, { color: theme.valueText }]}>{data.repository.provider}</Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={[styles.label, { color: theme.labelText }]}>Active Branch:</Text>
              <Text style={styles.branchBadge}>{data.repository.branch}</Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={[styles.label, { color: theme.labelText }]}>Commit Tag:</Text>
              <Text style={styles.shaText}>{data.repository.commitSha}</Text>
            </View>
            
            {/* Added: Explicit Date & Time Timestamp processing field for Latest Tracking */}
            <View style={styles.metricRow}>
              <Text style={[styles.label, { color: theme.labelText }]}>Commit Date:</Text>
              <Text style={[styles.value, { color: theme.valueText, fontSize: 12 }]}>
                {data.repository.commitTimestamp || "2026-06-07 16:45:11"}
              </Text>
            </View>
            
            <Text style={[styles.commitMsg, { color: theme.commitMsgText }]} numberOfLines={1}>
              "{data.repository.lastCommitMessage}"
            </Text>
          </View>

          {/* Card 2: Cluster Health Tracker */}
          <View style={[styles.card, { backgroundColor: theme.cardBg, borderColor: theme.cardBorder }]}>
            <Text style={[styles.cardTitle, { color: theme.cardTitleText }]}>☸️ Cluster Health</Text>
            <View style={styles.metricRow}>
              <Text style={[styles.label, { color: theme.labelText }]}>Active Pods:</Text>
              <Text style={[styles.hugeValue, { color: theme.primaryText }]}>{data.cluster.activePods}</Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={[styles.label, { color: theme.labelText }]}>Pod Status:</Text>
              <Text style={[styles.statusBadge, { 
                backgroundColor: data.cluster.status === 'Running' ? 'rgba(76, 175, 80, 0.2)' : 'rgba(244, 67, 54, 0.2)',
                color: data.cluster.status === 'Running' ? '#4CAF50' : '#F44336'
              }]}>
                {data.cluster.status}
              </Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={[styles.label, { color: theme.labelText }]}>Restarts:</Text>
              <Text style={[styles.value, { color: theme.valueText }]}>{data.cluster.restarts}</Text>
            </View>
          </View>

          {/* Card 3: Live Resource Performance Monitoring */}
          <View style={[styles.card, { backgroundColor: theme.cardBg, borderColor: theme.cardBorder }]}>
            <Text style={[styles.cardTitle, { color: theme.cardTitleText }]}>📊 Performance Monitor</Text>
            <View style={styles.metricRow}>
              <Text style={[styles.label, { color: theme.labelText }]}>CPU Load:</Text>
              <Text style={[styles.value, { color: '#00E5FF' }]}>{data.resources.cpu}</Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={[styles.label, { color: theme.labelText }]}>RAM Usage:</Text>
              <Text style={[styles.value, { color: '#00E5FF' }]}>{data.resources.memory}</Text>
            </View>
            <View style={styles.progressBarBg}>
              <View style={styles.progressBarFill} />
            </View>
          </View>

          {/* Card 4: Helm Engine Output Configurations */}
          <View style={[styles.card, { backgroundColor: theme.cardBg, borderColor: theme.cardBorder }]}>
            <Text style={[styles.cardTitle, { color: theme.cardTitleText }]}>⛵ Helm Deployments</Text>
            <View style={styles.metricRow}>
              <Text style={[styles.label, { color: theme.labelText }]}>Release Tag:</Text>
              <Text style={[styles.value, { color: theme.valueText }]} numberOfLines={1}>{data.helm.chartName}</Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={[styles.label, { color: theme.labelText }]}>Deploy Status:</Text>
              <Text style={[styles.statusBadge, { backgroundColor: 'rgba(33, 150, 243, 0.2)', color: '#2196F3' }]}>
                {data.helm.status}
              </Text>
            </View>
          </View>

          {/* Card 5: Live Docker Hub Registry Tags (Full Width Extension) */}
          {data.dockerHubHistory && (
            <View style={[styles.fullWidthCard, { backgroundColor: theme.cardBg, borderColor: theme.cardBorder }]}> 
              <Text style={[styles.cardTitle, { color: theme.cardTitleText }]}>🐳 Docker Hub Image Registry</Text>
              <Text style={[styles.label, { marginBottom: 16, color: theme.labelText }]}>Repository: sujeymcw/expo-web-app</Text>
              
              {data.dockerHubHistory.map((img, index) => (
                <View key={index} style={styles.dockerRow}>
                  <Text style={styles.shaText} numberOfLines={1}>{img.name}</Text>
                  <View style={styles.dockerStats}>
                    <Text style={styles.dockerSizeBadge}>{img.size}</Text>
                    <Text style={[styles.value, { color: theme.valueText }]}>{img.pushed}</Text>
                  </View>
                </View>
              ))}
            </View>
          )}

        </View>

        {/* Dynamic Force Refresh Trigger Button */}
        <TouchableOpacity style={styles.refreshButton} onPress={() => setRefreshKey(prev => prev + 1)}>
          <Text style={styles.refreshButtonText}>🔄 Force Telemetry Sync</Text>
        </TouchableOpacity>

      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollContainer: {
    padding: 24,
    alignItems: 'center',
    width: '100%',
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  loadingText: {
    color: '#A0AEC0',
    marginTop: 16,
    fontSize: 14,
  },
  header: {
    width: '100%',
    maxWidth: 900,
    marginBottom: 32,
    marginTop: 16,
  },
  headerTopRow: {
    flexDirection: 'row',
    justifyContent: 'browser',
    justifyContent: 'space-between',
    alignItems: 'center',
    width: '100%',
  },
  mainTitle: {
    fontSize: 32,
    fontWeight: '800',
    letterSpacing: -0.5,
  },
  mainSubtitle: {
    fontSize: 16,
    marginTop: 4,
  },
  themeToggleButton: {
    paddingVertical: 8,
    paddingHorizontal: 14,
    borderRadius: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  themeToggleText: {
    fontSize: 12,
    fontWeight: '700',
  },
  syncStatusRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 14,
    paddingTop: 10,
    borderTopWidth: 1,
    borderTopColor: 'rgba(113, 128, 150, 0.15)',
    width: '100%',
  },
  syncStatusLabel: {
    fontSize: 13,
    fontWeight: '500',
  },
  syncTimeText: {
    fontSize: 12,
    fontFamily: 'monospace',
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    width: '100%',
    maxWidth: 900,
  },
  card: {
    borderWidth: 1,
    borderRadius: 16,
    padding: 24,
    width: '48%',
    minWidth: 280,
    marginBottom: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.2,
    shadowRadius: 12,
  },
  fullWidthCard: {
    borderWidth: 1,
    borderRadius: 16,
    padding: 24,
    width: '100%',
    minWidth: '100%',
    marginBottom: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.2,
    shadowRadius: 12,
    alignSelf: 'stretch',
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 20,
    letterSpacing: 0.2,
  },
  metricRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 14,
  },
  dockerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderBottomWidth: 1,
    borderBottomColor: '#2D3748',
    paddingBottom: 10,
    marginBottom: 10,
    width: '100%',
  },
  dockerStats: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  label: {
    fontSize: 14,
  },
  value: {
    fontSize: 14,
    fontWeight: '600',
  },
  hugeValue: {
    fontSize: 22,
    fontWeight: '800',
  },
  shaText: {
    fontFamily: 'monospace',
    color: '#A0AEC0',
    backgroundColor: '#2D3748',
    paddingVertical: 4,
    paddingHorizontal: 8,
    borderRadius: 6,
    fontSize: 13,
  },
  branchBadge: {
    color: '#FF9100',
    backgroundColor: 'rgba(255, 145, 0, 0.15)',
    paddingVertical: 2,
    paddingHorizontal: 8,
    borderRadius: 6,
    fontSize: 12,
    fontWeight: '600',
  },
  dockerSizeBadge: {
    color: '#00E5FF',
    backgroundColor: 'rgba(0, 229, 255, 0.1)',
    paddingVertical: 2,
    paddingHorizontal: 8,
    borderRadius: 6,
    fontSize: 12,
    fontWeight: '600',
    marginRight: 12,
  },
  statusBadge: {
    paddingVertical: 4,
    paddingHorizontal: 10,
    borderRadius: 8,
    fontSize: 12,
    fontWeight: '700',
    overflow: 'hidden',
  },
  commitMsg: {
    fontSize: 12,
    fontStyle: 'italic',
    marginTop: 8,
    borderTopWidth: 1,
    borderTopColor: 'rgba(113, 128, 150, 0.15)',
    paddingTop: 10,
  },
  progressBarBg: {
    height: 6,
    backgroundColor: '#2D3748',
    borderRadius: 3,
    marginTop: 12,
    overflow: 'hidden',
  },
  progressBarFill: {
    width: '35%',
    height: '100%',
    backgroundColor: '#00E5FF',
    borderRadius: 3,
  },
  refreshButton: {
    backgroundColor: '#2B6CB0',
    paddingVertical: 14,
    paddingHorizontal: 28,
    borderRadius: 12,
    marginTop: 16,
    shadowColor: '#2B6CB0',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
    marginBottom: 40,
    width: '100%',
    maxWidth: 900,
    alignItems: 'center',
  },
  refreshButtonText: {
    color: '#FFFFFF',
    fontWeight: '700',
    fontSize: 15,
  },
});