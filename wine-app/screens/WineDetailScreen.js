import React, { useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  Image, Linking, Alert,
} from 'react-native';
import { getFoodPairings } from '../services/wineApi';
import { addToWineLog } from '../services/storage';

export default function WineDetailScreen({ route, navigation }) {
  const { wine } = route.params;
  const [saved, setSaved] = useState(false);
  const pairings = getFoodPairings(wine);

  async function handleSave() {
    try {
      await addToWineLog(wine);
      setSaved(true);
      Alert.alert('Sparat!', `${wine.name} har lagts till i din vinlogg.`, [
        { text: 'OK' },
        { text: 'Visa logg', onPress: () => navigation.navigate('WineLog') },
      ]);
    } catch {
      Alert.alert('Fel', 'Kunde inte spara vinet.');
    }
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {wine.image && (
        <Image source={{ uri: wine.image }} style={styles.image} resizeMode="contain" />
      )}

      <View style={styles.header}>
        <Text style={styles.wineName}>{wine.name}</Text>
        {wine.producer ? <Text style={styles.producer}>{wine.producer}</Text> : null}
        {wine.vintage ? <Text style={styles.vintage}>Årgång {wine.vintage}</Text> : null}
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Grundinfo</Text>
        <InfoRow label="Land" value={wine.country} />
        <InfoRow label="Region" value={wine.region} />
        <InfoRow label="Druva(r)" value={wine.grapes} />
        <InfoRow label="Alkohol" value={wine.alcohol} />
        <InfoRow label="Volym" value={wine.volume} />
        <InfoRow label="Streckkod" value={wine.barcode} />
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Servering</Text>
        <InfoRow label="Temperatur" value={pairings.temp} />
        <InfoRow label="Tillfälle" value={pairings.occasion} />
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Passar till</Text>
        {pairings.pairings.map((p, i) => (
          <View key={i} style={styles.pairingRow}>
            <Text style={styles.checkmark}>✓</Text>
            <Text style={styles.pairingText}>{p}</Text>
          </View>
        ))}
        {pairings.avoid.length > 0 && (
          <>
            <Text style={[styles.cardTitle, { marginTop: 12 }]}>Passar inte till</Text>
            {pairings.avoid.map((a, i) => (
              <View key={i} style={styles.pairingRow}>
                <Text style={styles.cross}>✗</Text>
                <Text style={styles.avoidText}>{a}</Text>
              </View>
            ))}
          </>
        )}
      </View>

      <TouchableOpacity
        style={styles.systembolagetBtn}
        onPress={() => Linking.openURL(wine.storeLink)}
      >
        <Text style={styles.systembolagetText}>Sök på Systembolaget →</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={[styles.saveBtn, saved && styles.saveBtnDone]}
        onPress={handleSave}
        disabled={saved}
      >
        <Text style={styles.saveBtnText}>{saved ? '✓ Sparat i din vinlogg' : 'Spara i min vinlogg'}</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.scanAgainBtn}
        onPress={() => navigation.navigate('Scanner')}
      >
        <Text style={styles.scanAgainText}>Skanna ett nytt vin</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

function InfoRow({ label, value }) {
  if (!value) return null;
  return (
    <View style={styles.row}>
      <Text style={styles.label}>{label}</Text>
      <Text style={styles.value}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f5f0eb' },
  content: { padding: 16, paddingBottom: 40 },
  image: { width: '100%', height: 200, marginBottom: 8 },
  header: { marginBottom: 16 },
  wineName: { fontSize: 24, fontWeight: '700', color: '#1a0a0e', lineHeight: 30 },
  producer: { fontSize: 16, color: '#555', marginTop: 4 },
  vintage: { fontSize: 15, color: '#6B2737', marginTop: 2, fontWeight: '600' },
  card: {
    backgroundColor: '#fff',
    borderRadius: 14,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 2,
  },
  cardTitle: { fontSize: 13, fontWeight: '700', color: '#6B2737', textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 10 },
  row: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 5, borderBottomWidth: 1, borderBottomColor: '#f0ebe6' },
  label: { color: '#888', fontSize: 14, flex: 1 },
  value: { color: '#1a0a0e', fontSize: 14, fontWeight: '500', flex: 2, textAlign: 'right' },
  pairingRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 4 },
  checkmark: { color: '#2d7a3a', fontSize: 16, marginRight: 8 },
  cross: { color: '#c0392b', fontSize: 16, marginRight: 8 },
  pairingText: { color: '#1a0a0e', fontSize: 14 },
  avoidText: { color: '#666', fontSize: 14 },
  systembolagetBtn: {
    backgroundColor: '#006400',
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
    marginBottom: 10,
  },
  systembolagetText: { color: '#fff', fontSize: 15, fontWeight: '600' },
  saveBtn: {
    backgroundColor: '#6B2737',
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
    marginBottom: 10,
  },
  saveBtnDone: { backgroundColor: '#2d7a3a' },
  saveBtnText: { color: '#fff', fontSize: 15, fontWeight: '600' },
  scanAgainBtn: {
    borderWidth: 1.5,
    borderColor: '#6B2737',
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
  },
  scanAgainText: { color: '#6B2737', fontSize: 15, fontWeight: '600' },
});
