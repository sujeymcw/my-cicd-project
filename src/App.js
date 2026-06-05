import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ActivityIndicator, ScrollView, SafeAreaView, TouchableOpacity } from 'react-native';
import { StatusBar } from 'expo-status-bar';

export default function App() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    // Poll the local Python API data bridge
    fetch('http://127.0.0.1:8000/api/metrics')
      .then((res) => res.json())
      .then((json) => {
        setData(json);
        setLoading(false);
      })
      .catch((err) => {
        console.error("API Error: Make sure your Python backend is running!", err);
      });
  }, [refreshKey]);

  if (loading || !data) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#00E5FF" />
        <Text style={styles.loadingText}>Connecting to Cluster Control Plane...</Text>
      </View>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar style="light" />
      <ScrollView contentContainerStyle={styles.scrollContainer}>
        
        {/* Header Dashboard Title */}
        <View style={styles.header}>
          <Text style={styles.mainTitle}>🎛️ Control Plane</Text>
          <Text style={styles.mainSubtitle}>Live DevOps Telemetry Engine</Text>
        </View>

        {/* Dashboard Responsive Grid */}
        <View style={styles.grid}>
          
          {/* Card 1: Git Repository Data */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>📁 Repository Hub</Text>
            <View style={styles.metricRow}>
              <Text style={styles.label}>Source:</Text>
              <Text style={styles.value}>{data.repository.provider}</Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={styles.label}>Active Branch:</Text>
              <Text style={styles.branchBadge}>{data.repository.branch}</Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={styles.label}>Commit Tag:</Text>
              <Text style={styles.shaText}>{data.repository.commitSha}</Text>
            </View>
            <Text style={styles.commitMsg} numberOfLines={1}>"{data.repository.lastCommitMessage}"</Text>
          </View>

          {/* Card 2: Cluster Health Tracker */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>☸️ Cluster Health</Text>
            <View style={styles.metricRow}>
              <Text style={styles.label}>Active Pods:</Text>
              <Text style={styles.hugeValue}>{data.cluster.activePods}</Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={styles.label}>Pod Status:</Text>
              <Text style={[styles.statusBadge, { 
                backgroundColor: data.cluster.status === 'Running' ? 'rgba(76, 175, 80, 0.2)' : 'rgba(244, 67, 54, 0.2)',
                color: data.cluster.status === 'Running' ? '#4CAF50' : '#F44336'
              }]}>
                {data.cluster.status}
              </Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={styles.label}>Restarts:</Text>
              <Text style={styles.value}>{data.cluster.restarts}</Text>
            </View>
          </View>

          {/* Card 3: Live Resource Performance Monitoring */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>📊 Performance Monitor</Text>
            <View style={styles.metricRow}>
              <Text style={styles.label}>CPU Load:</Text>
              <Text style={[styles.value, { color: '#00E5FF' }]}>{data.resources.cpu}</Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={styles.label}>RAM Usage:</Text>
              <Text style={[styles.value, { color: '#00E5FF' }]}>{data.resources.memory}</Text>
            </View>
            <View style={styles.progressBarBg}>
              <View style={styles.progressBarFill} />
            </View>
          </View>

          {/* Card 4: Helm Engine Output Configurations */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>⛵ Helm Deployments</Text>
            <View style={styles.metricRow}>
              <Text style={styles.label}>Release Tag:</Text>
              <Text style={styles.value} numberOfLines={1}>{data.helm.chartName}</Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={styles.label}>Deploy Status:</Text>
              <Text style={[styles.statusBadge, { backgroundColor: 'rgba(33, 150, 243, 0.2)', color: '#2196F3' }]}>
                {data.helm.status}
              </Text>
            </View>
          </View>

          {/* Card 5: Live Docker Hub Registry Tags (Full Width Extension) */}
          {data.dockerHubHistory && (
            <View style={styles.fullWidthCard}> 
              <Text style={styles.cardTitle}>🐳 Docker Hub Image Registry</Text>
              <Text style={[styles.label, { marginBottom: 16 }]}>Repository: sujeymcw/expo-web-app</Text>
              
              {data.dockerHubHistory.map((img, index) => (
                <View key={index} style={styles.dockerRow}>
                  <Text style={styles.shaText} numberOfLines={1}>{img.name}</Text>
                  <View style={styles.dockerStats}>
                    <Text style={styles.dockerSizeBadge}>{img.size}</Text>
                    <Text style={styles.value}>{img.pushed}</Text>
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
    backgroundColor: '#0A0E17', // Deeper cyber dark theme color palette
  },
  scrollContainer: {
    padding: 24,
    alignItems: 'center',
    width: '100%',
  },
  center: {
    flex: 1,
    backgroundColor: '#0A0E17',
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
  mainTitle: {
    fontSize: 32,
    fontWeight: '800',
    color: '#FFFFFF',
    letterSpacing: -0.5,
  },
  mainSubtitle: {
    fontSize: 16,
    color: '#718096',
    marginTop: 4,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    width: '100%',
    maxWidth: 900,
  },
  card: {
    backgroundColor: 'rgba(26, 32, 44, 0.6)', // Glassmorphism backdrop filter support
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.05)',
    borderRadius: 16,
    padding: 24,
    width: '48%',
    minWidth: 280,
    marginBottom: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
  },
  fullWidthCard: {
    backgroundColor: 'rgba(26, 32, 44, 0.6)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.05)',
    borderRadius: 16,
    padding: 24,
    width: '100%',
    minWidth: '100%',
    marginBottom: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    alignSelf: 'stretch',
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#EDF2F7',
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
    color: '#718096',
    fontSize: 14,
  },
  value: {
    color: '#E2E8F0',
    fontSize: 14,
    fontWeight: '600',
  },
  hugeValue: {
    fontSize: 22,
    fontWeight: '800',
    color: '#FFF',
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
    color: '#4A5568',
    fontSize: 12,
    fontStyle: 'italic',
    marginTop: 8,
    borderTopWidth: 1,
    borderTopColor: '#2D3748',
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
  },
  refreshButtonText: {
    color: '#FFFFFF',
    fontWeight: '700',
    fontSize: 15,
  },
});