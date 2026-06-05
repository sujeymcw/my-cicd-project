import React from 'react';
import { StyleSheet, Text, View, SafeAreaView } from 'react-native';
import { StatusBar } from 'expo-status-bar';

export default function App() {
  return (
    <SafeAreaView style={styles.container}>
      <StatusBar style="light" />
      
      <View style={styles.card}>
        <Text style={styles.title}>🚀 Pipeline Success!</Text>
        <Text style={styles.subtitle}>
          Your Expo application has been successfully compiled, dockerized, and delivered via Helm into Kubernetes.
        </Text>
        
        <View style={styles.badgeContainer}>
          <View style={[styles.badge, { backgroundColor: '#4CAF50' }]}>
            <Text style={styles.badgeText}>Docker: Live</Text>
          </View>
          <View style={[styles.badge, { backgroundColor: '#008786' }]}>
            <Text style={styles.badgeText}>Helm: v3</Text>
          </View>
          <View style={[styles.badge, { backgroundColor: '#2196F3' }]}>
            <Text style={styles.badgeText}>K8s: Ready</Text>
          </View>
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#121212', // Clean modern dark theme background
    alignItems: 'center',
    justifyContent: 'center',
  },
  card: {
    backgroundColor: '#1E1E1E',
    padding: 30,
    borderRadius: 16,
    width: '90%',
    maxWidth: 450,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 5,
    elevation: 8,
    borderWidth: 1,
    borderColor: '#333333',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 12,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 15,
    color: '#A0A0A0',
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: 24,
  },
  badgeContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '100%',
  },
  badge: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 20,
    minWidth: 90,
    alignItems: 'center',
  },
  badgeText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
  },
});