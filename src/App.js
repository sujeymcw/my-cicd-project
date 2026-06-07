import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ActivityIndicator, ScrollView, SafeAreaView, TouchableOpacity, Switch, Alert } from 'react-native';
import { StatusBar } from 'expo-status-bar';

export default function App() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [refreshKey, setRefreshKey] = useState(0);

  // New Interactive State Additions
  const [isDisrupted, setIsDisrupted] = useState(false);
  const [isRollingBack, setIsRollingBack] = useState(false);
  const [showRollbackDrawer, setShowRollbackDrawer] = useState(false);
  const [selectedVersion, setSelectedVersion] = useState('v1.0.0');

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

  // Interactive Trigger 1: Pod Restarts simulation handler
  const handlePodCycle = () => {
    if (!data) return;
    
    // Optimistically set status to pending/cycling
    const originalStatus = data.cluster.status;
    setData(prev => ({
      ...prev,
      cluster: {
        ...prev.cluster,
        status: 'Terminating',
        restarts: prev.cluster.restarts + 1
      }
    }));

    setTimeout(() => {
      setData(prev => ({
        ...prev,
        cluster: { ...prev.cluster, status: 'ContainerCreating' }
      }));
      
      setTimeout(() => {
        setData(prev => ({
          ...prev,
          cluster: { ...prev.cluster, status: 'Running' }
        }));
        Alert.alert("Cluster Status Update", "Pod recycled successfully. New container verified running.");
      }, 1500);
    }, 1200);
  };

  // Interactive Trigger 2: Helm rollback handler
  const handleRollbackExecute = (version) => {
    setIsRollingBack(true);
    Alert.alert(
      "Confirm GitOps Rollback",
      `Are you sure you want to rollback helm release ${data.helm.chartName} to stable build ${version}?`,
      [
        { text: "Cancel", onPress: () => setIsRollingBack(false), style: "cancel" },
        { 
          text: "Execute Rollback", 
          onPress: () => {
            setTimeout(() => {
              setIsRollingBack(false);
              setShowRollbackDrawer(false);
              Alert.alert("Success", `Helm configuration rolled back to ${version} successfully.`);
            }, 2000);
          }
        }
      ]
    );
  };

  // Interactive Trigger 3: Disruption simulation webhook post
  const toggleDisruptionGate = (value) => {
    setIsDisrupted(value);
    
    // Optionally fire an immediate telemetry post to Python backend to change operational metrics
    fetch('http://127.0.0.1:8000/api/disrupt', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ disrupted: value })
    })
    .then(() => {
      const stateMsg = value ? "Pipeline disruption flag armed. Next push will fail." : "Pipeline safe. Disruption flags cleared.";
      Alert.alert("Chaos Engineering Lab", stateMsg);
    })
    .catch(() => {
      // Graceful fallback if backend endpoint isn't fully bound yet
      Alert.alert("Chaos Engineering Lab", value ? "Disruption simulation active locally." : "Disruption simulation stopped.");
    });
  };

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

          {/* Card 2: Cluster Health Tracker (Enhanced with Pod Cycler Interaction) */}
          <View style={styles.card}>
            <View style={styles.cardTitleHeaderRow}>
              <Text style={styles.cardTitle}>☸️ Cluster Health</Text>
              <TouchableOpacity onPress={handlePodCycle} style={styles.inlineActionButton}>
                <Text style={styles.inlineActionText}>🔄 Cycle Pod</Text>
              </TouchableOpacity>
            </View>
            <View style={styles.metricRow}>
              <Text style={styles.label}>Active Pods:</Text>
              <Text style={styles.hugeValue}>{data.cluster.activePods}</Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={styles.label}>Pod Status:</Text>
              <Text style={[styles.statusBadge, { 
                backgroundColor: data.cluster.status === 'Running' ? 'rgba(76, 175, 80, 0.2)' : data.cluster.status === 'Terminating' ? 'rgba(251, 140, 0, 0.2)' : 'rgba(244, 67, 54, 0.2)',
                color: data.cluster.status === 'Running' ? '#4CAF50' : data.cluster.status === 'Terminating' ? '#FB8C00' : '#F44336'
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

          {/* Card 4: Helm Engine Output Configurations (Enhanced with Rollback Trigger Drawer) */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>⛵ Helm Deployments</Text>
            <View style={styles.metricRow}>
              <Text style={styles.label}>Release Tag:</Text>
              <Text style={styles.value} numberOfLines={1}>{data.helm.chartName}</Text>
            </View>
            <View style={styles.metricRow}>
              <Text style={styles.label}>Deploy Status:</Text>
              <TouchableOpacity onPress={() => setShowRollbackDrawer(!showRollbackDrawer)}>
                <Text style={[styles.statusBadge, { backgroundColor: 'rgba(33, 150, 243, 0.2)', color: '#2196F3', textDecorationLine: 'underline' }]}>
                  {data.helm.status} (Manage)
                </Text>
              </TouchableOpacity>
            </View>
          </View>

          {/* Hidden Drawer Extension: Helm GitOps Rollback Target Controls */}
          {showRollbackDrawer && (
            <View style={styles.fullWidthCard}>
              <Text style={[styles.cardTitle, { color: '#2196F3' }]}>⏪ GitOps Version Rollback Engine</Text>
              <Text style={[styles.label, { marginBottom: 14 }]}>Select target deployment history checkpoint:</Text>
              
              <View style={styles.versionSelectorRow}>
                {['v1.0.0', 'v0.9.9', 'v0.9.8'].map((version) => (
                  <TouchableOpacity 
                    key={version} 
                    style={[styles.versionOption, selectedVersion === version && styles.versionOptionSelected]}
                    onPress={() => setSelectedVersion(version)}
                  >
                    <Text style={[styles.versionOptionText, selectedVersion === version && styles.versionOptionTextSelected]}>{version}</Text>
                  </TouchableOpacity>
                ))}
              </View>

              <TouchableOpacity 
                style={[styles.actionButton, { backgroundColor: '#2196F3' }]} 
                onPress={() => handleRollbackExecute(selectedVersion)}
                disabled={isRollingBack}
              >
                {isRollingBack ? (
                  <ActivityIndicator size="small" color="#FFF" />
                ) : (
                  <Text style={styles.refreshButtonText}>Confirm Rollback to {selectedVersion}</Text>
                )}
              </TouchableOpacity>
            </View>
          )}

          {/* Card 5: Live Docker Hub Registry Tags */}
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

        {/* Chaos Engineering Experiment System Interaction Block */}
        <View style={styles.chaosContainer}>
          <Text style={styles.chaosLabel}>⚠️ Inject Simulated Infrastructure Disruption</Text>
          <Switch
            value={isDisrupted}
            onValueChange={toggleDisruptionGate}
            trackColor={{ false: '#2D3748', true: '#E53E3E' }}
            thumbColor={isDisrupted ? '#FFF' : '#A0AEC0'}
          />
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
    backgroundColor: '#0A0E17', 
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
    backgroundColor: 'rgba(26, 32, 44, 0.6)', 
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
  cardTitleHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
    width: '100%',
  },
  inlineActionButton: {
    backgroundColor: 'rgba(0, 229, 255, 0.1)',
    paddingVertical: 4,
    paddingHorizontal: 8,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: 'rgba(0, 229, 255, 0.2)',
  },
  inlineActionText: {
    color: '#00E5FF',
    fontSize: 11,
    fontWeight: '700',
  },
  versionSelectorRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 16,
    width: '100%',
  },
  versionOption: {
    backgroundColor: '#2D3748',
    paddingVertical: 10,
    borderRadius: 8,
    flex: 1,
    alignItems: 'center',
    marginHorizontal: 4,
    borderWidth: 1,
    borderColor: 'transparent',
  },
  versionOptionSelected: {
    backgroundColor: 'rgba(33, 150, 243, 0.15)',
    borderColor: '#2196F3',
  },
  versionOptionText: {
    color: '#A0AEC0',
    fontWeight: '600',
    fontSize: 13,
  },
  versionOptionTextSelected: {
    color: '#2196F3',
  },
  actionButton: {
    width: '100%',
    paddingVertical: 12,
    borderRadius: 10,
    alignItems: 'center',
    marginTop: 8,
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
  chaosContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    width: '100%',
    maxWidth: 900,
    backgroundColor: 'rgba(229, 62, 62, 0.08)',
    borderWidth: 1,
    borderColor: 'rgba(229, 62, 62, 0.2)',
    borderRadius: 12,
    paddingVertical: 14,
    paddingHorizontal: 20,
    marginTop: 8,
    marginBottom: 12,
  },
  chaosLabel: {
    color: '#E53E3E',
    fontWeight: '600',
    fontSize: 13,
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