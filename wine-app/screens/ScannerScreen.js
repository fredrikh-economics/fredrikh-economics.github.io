import React, { useState, useEffect, useRef } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity, ActivityIndicator, Alert, Linking,
} from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { lookupBarcode } from '../services/wineApi';

export default function ScannerScreen({ navigation }) {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanning, setScanning] = useState(true);
  const [loading, setLoading] = useState(false);
  const lastScan = useRef(null);

  useEffect(() => {
    const unsubscribe = navigation.addListener('focus', () => {
      setScanning(true);
      lastScan.current = null;
    });
    return unsubscribe;
  }, [navigation]);

  if (!permission) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6B2737" />
      </View>
    );
  }

  if (!permission.granted) {
    return (
      <View style={styles.center}>
        <Text style={styles.permTitle}>Kamera behövs</Text>
        <Text style={styles.permText}>
          VinScanner behöver tillgång till kameran för att skanna streckkoder.
        </Text>
        <TouchableOpacity style={styles.button} onPress={requestPermission}>
          <Text style={styles.buttonText}>Tillåt kamera</Text>
        </TouchableOpacity>
      </View>
    );
  }

  async function handleBarcode({ data, type }) {
    if (!scanning || loading || data === lastScan.current) return;
    lastScan.current = data;
    setScanning(false);
    setLoading(true);

    try {
      const wine = await lookupBarcode(data);
      if (wine) {
        navigation.navigate('WineDetail', { wine });
      } else {
        Alert.alert(
          'Vin hittades inte',
          `Streckkod: ${data}\n\nVinet finns inte i databasen. Sök manuellt på Systembolaget?`,
          [
            {
              text: 'Sök på Systembolaget',
              onPress: () => Linking.openURL(`https://www.systembolaget.se/sok/?searchQuery=${data}`),
            },
            { text: 'Skanna igen', onPress: () => { setScanning(true); lastScan.current = null; } },
          ]
        );
      }
    } catch (e) {
      Alert.alert('Fel', 'Kunde inte hämta information. Kontrollera internetanslutning.', [
        { text: 'Försök igen', onPress: () => { setScanning(true); lastScan.current = null; } },
      ]);
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={styles.container}>
      <CameraView
        style={StyleSheet.absoluteFillObject}
        facing="back"
        barcodeScannerSettings={{ barcodeTypes: ['ean13', 'ean8', 'upc_a', 'upc_e'] }}
        onBarcodeScanned={scanning ? handleBarcode : undefined}
      />

      <View style={styles.overlay}>
        <View style={styles.topArea}>
          <Text style={styles.title}>VinScanner</Text>
          <Text style={styles.hint}>Rikta kameran mot streckkoden på flaskan</Text>
        </View>

        <View style={styles.scanArea}>
          <View style={[styles.corner, styles.topLeft]} />
          <View style={[styles.corner, styles.topRight]} />
          <View style={[styles.corner, styles.bottomLeft]} />
          <View style={[styles.corner, styles.bottomRight]} />
          {loading && (
            <View style={styles.loadingOverlay}>
              <ActivityIndicator size="large" color="#fff" />
              <Text style={styles.loadingText}>Hämtar info...</Text>
            </View>
          )}
        </View>

        <View style={styles.bottomArea}>
          <Text style={styles.hint}>EAN-13 streckkod</Text>
        </View>
      </View>
    </View>
  );
}

const CORNER_SIZE = 28;
const CORNER_WIDTH = 4;

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24, backgroundColor: '#1a0a0e' },
  overlay: { flex: 1, justifyContent: 'space-between' },
  topArea: {
    alignItems: 'center',
    paddingTop: 60,
    paddingHorizontal: 20,
    backgroundColor: 'rgba(0,0,0,0.55)',
    paddingBottom: 20,
  },
  title: { color: '#fff', fontSize: 26, fontWeight: '700', letterSpacing: 1 },
  hint: { color: 'rgba(255,255,255,0.8)', fontSize: 14, marginTop: 6, textAlign: 'center' },
  scanArea: {
    width: 260,
    height: 160,
    alignSelf: 'center',
  },
  corner: {
    position: 'absolute',
    width: CORNER_SIZE,
    height: CORNER_SIZE,
    borderColor: '#fff',
  },
  topLeft: { top: 0, left: 0, borderTopWidth: CORNER_WIDTH, borderLeftWidth: CORNER_WIDTH },
  topRight: { top: 0, right: 0, borderTopWidth: CORNER_WIDTH, borderRightWidth: CORNER_WIDTH },
  bottomLeft: { bottom: 0, left: 0, borderBottomWidth: CORNER_WIDTH, borderLeftWidth: CORNER_WIDTH },
  bottomRight: { bottom: 0, right: 0, borderBottomWidth: CORNER_WIDTH, borderRightWidth: CORNER_WIDTH },
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.6)',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 4,
  },
  loadingText: { color: '#fff', marginTop: 8, fontSize: 14 },
  bottomArea: {
    alignItems: 'center',
    paddingBottom: 40,
    backgroundColor: 'rgba(0,0,0,0.55)',
    paddingTop: 20,
  },
  permTitle: { color: '#fff', fontSize: 22, fontWeight: '700', marginBottom: 12, textAlign: 'center' },
  permText: { color: 'rgba(255,255,255,0.7)', fontSize: 15, textAlign: 'center', marginBottom: 30, lineHeight: 22 },
  button: { backgroundColor: '#6B2737', paddingHorizontal: 32, paddingVertical: 14, borderRadius: 12 },
  buttonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
});
