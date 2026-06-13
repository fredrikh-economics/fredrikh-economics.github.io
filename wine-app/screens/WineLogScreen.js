import React, { useState, useCallback } from 'react';
import {
  View, Text, StyleSheet, FlatList, TouchableOpacity,
  Alert, TextInput, Modal,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { getWineLog, updateWineEntry, deleteWineEntry } from '../services/storage';

export default function WineLogScreen({ navigation }) {
  const [log, setLog] = useState([]);
  const [editingId, setEditingId] = useState(null);
  const [noteText, setNoteText] = useState('');
  const [ratingValue, setRatingValue] = useState('');

  useFocusEffect(
    useCallback(() => {
      getWineLog().then(setLog);
    }, [])
  );

  async function handleDelete(id, name) {
    Alert.alert('Ta bort', `Ta bort ${name} från loggen?`, [
      { text: 'Avbryt', style: 'cancel' },
      {
        text: 'Ta bort',
        style: 'destructive',
        onPress: async () => {
          await deleteWineEntry(id);
          setLog(prev => prev.filter(w => w.id !== id));
        },
      },
    ]);
  }

  async function handleSaveNote() {
    const rating = parseFloat(ratingValue);
    await updateWineEntry(editingId, {
      notes: noteText,
      rating: isNaN(rating) ? null : Math.min(5, Math.max(0, rating)),
    });
    setLog(prev => prev.map(w =>
      w.id === editingId
        ? { ...w, notes: noteText, rating: isNaN(rating) ? null : Math.min(5, Math.max(0, rating)) }
        : w
    ));
    setEditingId(null);
  }

  function openEdit(wine) {
    setEditingId(wine.id);
    setNoteText(wine.notes || '');
    setRatingValue(wine.rating?.toString() || '');
  }

  function renderStars(rating) {
    if (rating == null) return '–';
    const full = Math.round(rating);
    return '★'.repeat(full) + '☆'.repeat(5 - full);
  }

  function formatDate(iso) {
    const d = new Date(iso);
    return d.toLocaleDateString('sv-SE', { day: 'numeric', month: 'short', year: 'numeric' });
  }

  if (log.length === 0) {
    return (
      <View style={styles.empty}>
        <Text style={styles.emptyIcon}>🍷</Text>
        <Text style={styles.emptyTitle}>Ingen vinlogg ännu</Text>
        <Text style={styles.emptyText}>Skanna ett vin och spara det så dyker det upp här.</Text>
        <TouchableOpacity style={styles.scanBtn} onPress={() => navigation.navigate('Scanner')}>
          <Text style={styles.scanBtnText}>Skanna ett vin</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={log}
        keyExtractor={item => item.id}
        contentContainerStyle={styles.list}
        renderItem={({ item }) => (
          <View style={styles.card}>
            <View style={styles.cardTop}>
              <View style={styles.cardInfo}>
                <Text style={styles.wineName} numberOfLines={2}>{item.name}</Text>
                {item.producer ? <Text style={styles.producer}>{item.producer}</Text> : null}
                <Text style={styles.date}>{formatDate(item.dateTasted)}</Text>
              </View>
              <View style={styles.cardRight}>
                <Text style={styles.stars}>{renderStars(item.rating)}</Text>
                {item.vintage ? <Text style={styles.vintage}>{item.vintage}</Text> : null}
              </View>
            </View>

            {item.notes ? (
              <Text style={styles.notes}>"{item.notes}"</Text>
            ) : null}

            <View style={styles.actions}>
              <TouchableOpacity style={styles.editBtn} onPress={() => openEdit(item)}>
                <Text style={styles.editBtnText}>Anteckning & betyg</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={() => handleDelete(item.id, item.name)}>
                <Text style={styles.deleteBtn}>Ta bort</Text>
              </TouchableOpacity>
            </View>
          </View>
        )}
      />

      <Modal visible={editingId !== null} animationType="slide" transparent>
        <View style={styles.modalBg}>
          <View style={styles.modal}>
            <Text style={styles.modalTitle}>Anteckning & betyg</Text>
            <Text style={styles.modalLabel}>Betyg (0–5)</Text>
            <TextInput
              style={styles.input}
              value={ratingValue}
              onChangeText={setRatingValue}
              keyboardType="decimal-pad"
              placeholder="t.ex. 4.5"
              placeholderTextColor="#aaa"
            />
            <Text style={styles.modalLabel}>Dina anteckningar</Text>
            <TextInput
              style={[styles.input, styles.textArea]}
              value={noteText}
              onChangeText={setNoteText}
              multiline
              placeholder="Smakade av körsbär, bra med lammet..."
              placeholderTextColor="#aaa"
            />
            <TouchableOpacity style={styles.saveBtn} onPress={handleSaveNote}>
              <Text style={styles.saveBtnText}>Spara</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.cancelBtn} onPress={() => setEditingId(null)}>
              <Text style={styles.cancelBtnText}>Avbryt</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f5f0eb' },
  list: { padding: 16, paddingBottom: 40 },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 32, backgroundColor: '#f5f0eb' },
  emptyIcon: { fontSize: 52, marginBottom: 16 },
  emptyTitle: { fontSize: 20, fontWeight: '700', color: '#1a0a0e', marginBottom: 8 },
  emptyText: { color: '#666', textAlign: 'center', lineHeight: 22, marginBottom: 24 },
  scanBtn: { backgroundColor: '#6B2737', paddingHorizontal: 28, paddingVertical: 13, borderRadius: 12 },
  scanBtnText: { color: '#fff', fontSize: 15, fontWeight: '600' },
  card: {
    backgroundColor: '#fff',
    borderRadius: 14,
    padding: 14,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 2,
  },
  cardTop: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 8 },
  cardInfo: { flex: 1, marginRight: 12 },
  wineName: { fontSize: 16, fontWeight: '700', color: '#1a0a0e' },
  producer: { fontSize: 13, color: '#777', marginTop: 2 },
  date: { fontSize: 12, color: '#aaa', marginTop: 4 },
  cardRight: { alignItems: 'flex-end' },
  stars: { fontSize: 16, color: '#c0a040' },
  vintage: { fontSize: 12, color: '#6B2737', marginTop: 4, fontWeight: '600' },
  notes: { color: '#555', fontSize: 13, fontStyle: 'italic', marginBottom: 8, lineHeight: 18 },
  actions: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  editBtn: { backgroundColor: '#f0ebe6', paddingHorizontal: 14, paddingVertical: 7, borderRadius: 8 },
  editBtnText: { color: '#6B2737', fontSize: 13, fontWeight: '600' },
  deleteBtn: { color: '#c0392b', fontSize: 13 },
  modalBg: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  modal: { backgroundColor: '#fff', borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: 24, paddingBottom: 40 },
  modalTitle: { fontSize: 18, fontWeight: '700', color: '#1a0a0e', marginBottom: 16 },
  modalLabel: { fontSize: 13, color: '#888', marginBottom: 6, marginTop: 8, fontWeight: '600', textTransform: 'uppercase' },
  input: { borderWidth: 1, borderColor: '#e0d8d0', borderRadius: 10, padding: 12, fontSize: 15, color: '#1a0a0e', marginBottom: 4 },
  textArea: { height: 100, textAlignVertical: 'top' },
  saveBtn: { backgroundColor: '#6B2737', borderRadius: 12, padding: 14, alignItems: 'center', marginTop: 16 },
  saveBtnText: { color: '#fff', fontSize: 15, fontWeight: '600' },
  cancelBtn: { padding: 14, alignItems: 'center' },
  cancelBtnText: { color: '#888', fontSize: 15 },
});
