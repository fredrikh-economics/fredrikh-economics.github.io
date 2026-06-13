import React, { useState, useRef } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  ActivityIndicator, Alert, Linking, FlatList, TextInput,
  Modal, SafeAreaView, StatusBar,
} from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';

// ─── Systembolaget API-nyckel ─────────────────────────────────────────────────
// Registrera gratis på: https://api-portal.systembolaget.se/signup/
// Klistra in din nyckel här när du fått den:
const SYSTEMBOLAGET_API_KEY = '';

// ─── Wine API ────────────────────────────────────────────────────────────────

async function lookupByBarcode(barcode) {
  // 1. Prova Open Food Facts (internationell databas)
  try {
    const res = await fetch(`https://world.openfoodfacts.org/api/v0/product/${barcode}.json`);
    const data = await res.json();
    if (data.status === 1) {
      const p = data.product;
      const name = p.product_name || p.product_name_sv || p.product_name_en || '';
      if (name) {
        return {
          source: 'openfoodfacts',
          barcode,
          name,
          producer: p.brands || '',
          country: (p.countries_tags?.[0] || '').replace('en:', ''),
          region: p.manufacturing_places || '',
          vintage: (name.match(/\b(19|20)\d{2}\b/) || [])[0] || '',
          alcohol: p.nutriments?.alcohol ? `${p.nutriments.alcohol}%` : '',
          grapes: extractGrapes(p.ingredients_text || '', p.labels || ''),
          volume: p.quantity || '750 ml',
          price: '',
          taste: '',
          foodPairings: [],
          categories: p.categories || '',
          productId: '',
          storeLink: `https://www.systembolaget.se/sok/?searchQuery=${encodeURIComponent(name)}`,
        };
      }
    }
  } catch {}

  // 2. Prova Systembolaget (om API-nyckel finns)
  if (SYSTEMBOLAGET_API_KEY) {
    try {
      const sbWine = await lookupSystembolaget(barcode);
      if (sbWine) return sbWine;
    } catch {}
  }

  return null;
}

async function lookupSystembolaget(query) {
  const res = await fetch(
    `https://api-extern.systembolaget.se/sb-api-ecommerce/v1/productsearch/search?searchQuery=${encodeURIComponent(query)}&size=1`,
    { headers: { 'Ocp-Apim-Subscription-Key': SYSTEMBOLAGET_API_KEY } }
  );
  const data = await res.json();
  const products = data.products || [];
  if (products.length === 0) return null;

  const p = products[0];
  const name = [p.productNameBold, p.productNameThin].filter(Boolean).join(' ');
  const productId = p.productId || '';

  return {
    source: 'systembolaget',
    barcode: query,
    name,
    producer: p.producerName || p.supplierName || '',
    country: p.country || '',
    region: p.originLevel1 || '',
    subregion: p.originLevel2 || '',
    vintage: p.vintage ? String(p.vintage) : '',
    alcohol: p.alcoholPercentage ? `${p.alcoholPercentage}%` : '',
    grapes: Array.isArray(p.grapeGrapes) ? p.grapeGrapes.join(', ') : (p.grapeGrapes || ''),
    volume: p.volume ? `${p.volume} ml` : '',
    price: p.price ? `${p.price} kr` : '',
    taste: p.taste || '',
    foodPairings: Array.isArray(p.foodPairings) ? p.foodPairings : [],
    categories: p.categoryLevel1 || '',
    productId,
    storeLink: productId
      ? `https://www.systembolaget.se/sok/?searchQuery=${productId}`
      : `https://www.systembolaget.se/sok/?searchQuery=${encodeURIComponent(name)}`,
  };
}

function extractGrapes(ingredients, labels) {
  const text = (ingredients + ' ' + labels).toLowerCase();
  const grapes = [
    'cabernet sauvignon', 'merlot', 'pinot noir', 'syrah', 'shiraz',
    'chardonnay', 'sauvignon blanc', 'riesling', 'pinot gris', 'grenache',
    'tempranillo', 'sangiovese', 'malbec', 'zinfandel', 'viognier',
    'chenin blanc', 'muscat', 'moscato',
  ];
  return grapes
    .filter(g => text.includes(g))
    .map(g => g.charAt(0).toUpperCase() + g.slice(1))
    .join(', ');
}

function getFoodPairings(wine) {
  // Använd Systembolagets matparing om den finns
  if (wine.foodPairings && wine.foodPairings.length > 0) {
    return { pairings: wine.foodPairings, temp: getTemp(wine), occasion: '' };
  }
  // Annars gissa utifrån vintyp
  const t = (wine.categories + ' ' + wine.name + ' ' + wine.grapes + ' ' + wine.taste).toLowerCase();
  if (t.includes('champagne') || t.includes('sparkling') || t.includes('mousserande') || t.includes('prosecco'))
    return { pairings: ['Skaldjur', 'Sushi', 'Lax', 'Ostbricka'], temp: '6–8°C', occasion: 'Aperitif, fest' };
  if (t.includes('sauvignon blanc') || t.includes('riesling') || t.includes('pinot gris'))
    return { pairings: ['Getost', 'Fisk', 'Sallad', 'Skaldjur'], temp: '8–10°C', occasion: 'Sommarmat' };
  if (t.includes('chardonnay'))
    return { pairings: ['Hummer', 'Grillad fisk', 'Kyckling', 'Creamy pasta'], temp: '10–12°C', occasion: 'Finmiddag' };
  if (t.includes('pinot noir') || t.includes('bourgogne'))
    return { pairings: ['Anka', 'Lax', 'Svamp', 'Kalvkött'], temp: '14–16°C', occasion: 'Elegant middag' };
  if (t.includes('rosé') || t.includes('rose'))
    return { pairings: ['Grillad kyckling', 'Lätt pasta', 'Skaldjur'], temp: '8–10°C', occasion: 'Sommarmiddag' };
  if (t.includes('cabernet') || t.includes('merlot') || t.includes('shiraz') || t.includes('malbec'))
    return { pairings: ['Grillat nötkött', 'Lamm', 'Vilt', 'Lagrad ost'], temp: '16–18°C', occasion: 'BBQ, höstmiddag' };
  return { pairings: ['Prova till din favoriträtt!'], temp: '12–16°C', occasion: '' };
}

function getTemp(wine) {
  const t = (wine.categories + ' ' + wine.name).toLowerCase();
  if (t.includes('mousserande') || t.includes('champagne') || t.includes('rosé')) return '6–8°C';
  if (t.includes('vitt') || t.includes('white')) return '8–12°C';
  if (t.includes('rött') || t.includes('red')) return '16–18°C';
  return '12–16°C';
}

// ─── Enkel lagring (i minnet) ─────────────────────────────────────────────────

let wineLogData = [];

function saveWine(wine) {
  wineLogData = [{
    ...wine, id: Date.now().toString(),
    dateTasted: new Date().toISOString(), rating: null, notes: '',
  }, ...wineLogData];
  return wineLogData[0];
}

// ─── Scanner ──────────────────────────────────────────────────────────────────

function ScannerScreen({ onWineFound }) {
  const [permission, requestPermission] = useCameraPermissions();
  const [loading, setLoading] = useState(false);
  const lastScan = useRef(null);

  async function handleBarcode({ data }) {
    if (loading || data === lastScan.current) return;
    lastScan.current = data;
    setLoading(true);
    try {
      const wine = await lookupByBarcode(data);
      if (wine) {
        onWineFound(wine);
      } else {
        Alert.alert(
          'Vin hittades inte',
          `Streckkod: ${data}\n\n${!SYSTEMBOLAGET_API_KEY ? 'Tips: Lägg till Systembolagets API-nyckel för bättre träffar.' : ''}`,
          [
            { text: 'Sök på Systembolaget', onPress: () => Linking.openURL(`https://www.systembolaget.se/sok/?searchQuery=${data}`) },
            { text: 'Skanna igen', onPress: () => { lastScan.current = null; } },
          ]
        );
      }
    } catch {
      Alert.alert('Fel', 'Kontrollera internetanslutning.', [
        { text: 'OK', onPress: () => { lastScan.current = null; } },
      ]);
    } finally {
      setLoading(false);
    }
  }

  if (!permission) return <View style={s.center}><ActivityIndicator color="#6B2737" size="large" /></View>;

  if (!permission.granted) {
    return (
      <View style={s.center}>
        <Text style={s.permTitle}>Kamera behövs</Text>
        <Text style={s.permText}>VinScanner behöver kameran för att skanna streckkoder.</Text>
        <TouchableOpacity style={s.btn} onPress={requestPermission}>
          <Text style={s.btnText}>Tillåt kamera</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={{ flex: 1 }}>
      <CameraView
        style={StyleSheet.absoluteFillObject}
        facing="back"
        barcodeScannerSettings={{ barcodeTypes: ['ean13', 'ean8', 'upc_a', 'upc_e'] }}
        onBarcodeScanned={!loading ? handleBarcode : undefined}
      />
      <View style={s.scanOverlay}>
        <View style={s.scanTop}>
          <Text style={s.scanTitle}>VinScanner</Text>
          <Text style={s.scanHint}>Rikta mot streckkoden på flaskan</Text>
        </View>
        <View style={s.scanBox}>
          <View style={[s.corner, s.tl]} /><View style={[s.corner, s.tr]} />
          <View style={[s.corner, s.bl]} /><View style={[s.corner, s.br]} />
          {loading && (
            <View style={s.scanLoading}>
              <ActivityIndicator color="#fff" size="large" />
              <Text style={{ color: '#fff', marginTop: 8 }}>Hämtar info...</Text>
            </View>
          )}
        </View>
        <View style={s.scanBottom}>
          <Text style={s.scanHint}>EAN-13 streckkod</Text>
          {!SYSTEMBOLAGET_API_KEY && (
            <Text style={[s.scanHint, { fontSize: 11, color: 'rgba(255,200,100,0.9)', marginTop: 4 }]}>
              ⚠ Utan API-nyckel: begränsad databas
            </Text>
          )}
        </View>
      </View>
    </View>
  );
}

// ─── Vininfo ──────────────────────────────────────────────────────────────────

function WineDetailScreen({ wine, onScanAgain, onGoToLog }) {
  const [saved, setSaved] = useState(false);
  const pairings = getFoodPairings(wine);

  function handleSave() {
    saveWine(wine);
    setSaved(true);
    Alert.alert('Sparat!', `${wine.name} har lagts till i din vinlogg.`, [
      { text: 'OK' },
      { text: 'Visa logg', onPress: onGoToLog },
    ]);
  }

  return (
    <ScrollView style={s.detailBg} contentContainerStyle={{ padding: 16, paddingBottom: 40 }}>
      {wine.source === 'systembolaget' && (
        <View style={s.sourceBadge}>
          <Text style={s.sourceBadgeText}>✓ Systembolaget</Text>
        </View>
      )}

      <View style={{ marginBottom: 16 }}>
        <Text style={s.wineName}>{wine.name}</Text>
        {!!wine.producer && <Text style={s.producer}>{wine.producer}</Text>}
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 6 }}>
          {!!wine.vintage && <Badge text={`Årgång ${wine.vintage}`} />}
          {!!wine.price && <Badge text={wine.price} color="#2d7a3a" />}
          {!!wine.alcohol && <Badge text={wine.alcohol} color="#555" />}
        </View>
      </View>

      <Card title="Grundinfo">
        <Row label="Land" value={wine.country} />
        <Row label="Region" value={wine.region} />
        {!!wine.subregion && <Row label="Underregion" value={wine.subregion} />}
        <Row label="Druva(r)" value={wine.grapes} />
        <Row label="Volym" value={wine.volume} />
        <Row label="Streckkod" value={wine.barcode} />
        {!!wine.productId && <Row label="Art.nr Systembolaget" value={wine.productId} />}
      </Card>

      {!!wine.taste && (
        <Card title="Smakbeskrivning">
          <Text style={{ color: '#333', fontSize: 14, lineHeight: 20 }}>{wine.taste}</Text>
        </Card>
      )}

      <Card title="Servering">
        <Row label="Temperatur" value={pairings.temp} />
        {!!pairings.occasion && <Row label="Tillfälle" value={pairings.occasion} />}
      </Card>

      <Card title="Passar till">
        {pairings.pairings.map((item, i) => (
          <View key={i} style={{ flexDirection: 'row', paddingVertical: 3 }}>
            <Text style={{ color: '#2d7a3a', marginRight: 8, fontSize: 15 }}>✓</Text>
            <Text style={{ fontSize: 14, color: '#1a0a0e' }}>{item}</Text>
          </View>
        ))}
      </Card>

      <TouchableOpacity style={[s.btn, { backgroundColor: '#006400', marginBottom: 8 }]}
        onPress={() => Linking.openURL(wine.storeLink)}>
        <Text style={s.btnText}>
          {wine.source === 'systembolaget' ? 'Se på Systembolaget →' : 'Sök på Systembolaget →'}
        </Text>
      </TouchableOpacity>

      <TouchableOpacity style={[s.btn, saved && { backgroundColor: '#2d7a3a' }, { marginBottom: 8 }]}
        onPress={handleSave} disabled={saved}>
        <Text style={s.btnText}>{saved ? '✓ Sparat i din vinlogg' : 'Spara i min vinlogg'}</Text>
      </TouchableOpacity>

      <TouchableOpacity style={[s.btn, { backgroundColor: 'transparent', borderWidth: 1.5, borderColor: '#6B2737' }]}
        onPress={onScanAgain}>
        <Text style={[s.btnText, { color: '#6B2737' }]}>Skanna ett nytt vin</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

// ─── Vinlogg ──────────────────────────────────────────────────────────────────

function WineLogScreen({ onScan }) {
  const [log, setLog] = useState([...wineLogData]);
  const [editId, setEditId] = useState(null);
  const [noteText, setNoteText] = useState('');
  const [ratingValue, setRatingValue] = useState('');

  function refresh() { setLog([...wineLogData]); }

  function handleDelete(id, name) {
    Alert.alert('Ta bort', `Ta bort ${name}?`, [
      { text: 'Avbryt', style: 'cancel' },
      { text: 'Ta bort', style: 'destructive', onPress: () => { wineLogData = wineLogData.filter(w => w.id !== id); refresh(); } },
    ]);
  }

  function openEdit(wine) { setEditId(wine.id); setNoteText(wine.notes || ''); setRatingValue(wine.rating?.toString() || ''); }

  function saveNote() {
    const r = parseFloat(ratingValue);
    wineLogData = wineLogData.map(w =>
      w.id === editId ? { ...w, notes: noteText, rating: isNaN(r) ? null : Math.min(5, Math.max(0, r)) } : w
    );
    refresh();
    setEditId(null);
  }

  if (log.length === 0) {
    return (
      <View style={s.center}>
        <Text style={{ fontSize: 48, marginBottom: 16 }}>🍷</Text>
        <Text style={s.permTitle}>Ingen vinlogg ännu</Text>
        <Text style={s.permText}>Skanna ett vin och spara det så dyker det upp här.</Text>
        <TouchableOpacity style={s.btn} onPress={onScan}><Text style={s.btnText}>Skanna ett vin</Text></TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: '#f5f0eb' }}>
      <FlatList
        data={log}
        keyExtractor={i => i.id}
        contentContainerStyle={{ padding: 16, paddingBottom: 40 }}
        renderItem={({ item }) => (
          <View style={s.logCard}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 4 }}>
              <View style={{ flex: 1, marginRight: 8 }}>
                <Text style={{ fontSize: 15, fontWeight: '700', color: '#1a0a0e' }} numberOfLines={2}>{item.name}</Text>
                {!!item.producer && <Text style={{ fontSize: 12, color: '#777', marginTop: 2 }}>{item.producer}</Text>}
                <View style={{ flexDirection: 'row', gap: 6, marginTop: 4, flexWrap: 'wrap' }}>
                  {!!item.country && <Text style={s.tag}>{item.country}</Text>}
                  {!!item.vintage && <Text style={s.tag}>{item.vintage}</Text>}
                  {!!item.price && <Text style={[s.tag, { backgroundColor: '#e8f5e9', color: '#2d7a3a' }]}>{item.price}</Text>}
                </View>
              </View>
              <Text style={{ color: '#c0a040', fontSize: 16 }}>
                {item.rating != null ? '★'.repeat(Math.round(item.rating)) + '☆'.repeat(5 - Math.round(item.rating)) : '–'}
              </Text>
            </View>
            {!!item.notes && <Text style={{ color: '#555', fontSize: 13, fontStyle: 'italic', marginBottom: 8 }}>"{item.notes}"</Text>}
            <Text style={{ fontSize: 11, color: '#aaa', marginBottom: 6 }}>{new Date(item.dateTasted).toLocaleDateString('sv-SE')}</Text>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <TouchableOpacity style={s.editBtn} onPress={() => openEdit(item)}>
                <Text style={{ color: '#6B2737', fontSize: 13, fontWeight: '600' }}>Anteckning & betyg</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={() => handleDelete(item.id, item.name)}>
                <Text style={{ color: '#c0392b', fontSize: 13 }}>Ta bort</Text>
              </TouchableOpacity>
            </View>
          </View>
        )}
      />
      <Modal visible={editId !== null} animationType="slide" transparent>
        <View style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' }}>
          <View style={{ backgroundColor: '#fff', borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: 24, paddingBottom: 40 }}>
            <Text style={{ fontSize: 18, fontWeight: '700', marginBottom: 16 }}>Anteckning & betyg</Text>
            <Text style={s.modalLabel}>Betyg (0–5)</Text>
            <TextInput style={s.input} value={ratingValue} onChangeText={setRatingValue} keyboardType="decimal-pad" placeholder="t.ex. 4.5" placeholderTextColor="#aaa" />
            <Text style={s.modalLabel}>Dina anteckningar</Text>
            <TextInput style={[s.input, { height: 90, textAlignVertical: 'top' }]} value={noteText} onChangeText={setNoteText} multiline placeholder="Smakade av körsbär..." placeholderTextColor="#aaa" />
            <TouchableOpacity style={[s.btn, { marginTop: 16, marginBottom: 8 }]} onPress={saveNote}><Text style={s.btnText}>Spara</Text></TouchableOpacity>
            <TouchableOpacity style={{ padding: 12, alignItems: 'center' }} onPress={() => setEditId(null)}><Text style={{ color: '#888' }}>Avbryt</Text></TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

// ─── Delade komponenter ───────────────────────────────────────────────────────

function Card({ title, children }) {
  return (
    <View style={s.card}>
      <Text style={s.cardTitle}>{title}</Text>
      {children}
    </View>
  );
}

function Row({ label, value }) {
  if (!value) return null;
  return (
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 5, borderBottomWidth: 1, borderBottomColor: '#f0ebe6' }}>
      <Text style={{ color: '#888', fontSize: 14, flex: 1 }}>{label}</Text>
      <Text style={{ color: '#1a0a0e', fontSize: 14, fontWeight: '500', flex: 2, textAlign: 'right' }}>{value}</Text>
    </View>
  );
}

function Badge({ text, color = '#6B2737' }) {
  return (
    <View style={{ backgroundColor: color + '18', borderRadius: 6, paddingHorizontal: 8, paddingVertical: 3 }}>
      <Text style={{ color, fontSize: 13, fontWeight: '600' }}>{text}</Text>
    </View>
  );
}

// ─── App ──────────────────────────────────────────────────────────────────────

export default function App() {
  const [screen, setScreen] = useState('scanner');
  const [currentWine, setCurrentWine] = useState(null);

  function handleWineFound(wine) { setCurrentWine(wine); setScreen('detail'); }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#1a0a0e' }}>
      <StatusBar barStyle="light-content" />

      {screen === 'scanner' && <ScannerScreen onWineFound={handleWineFound} />}

      {screen === 'detail' && currentWine && (
        <View style={{ flex: 1 }}>
          <View style={s.detailHeader}>
            <TouchableOpacity onPress={() => setScreen('scanner')}><Text style={s.backBtn}>← Skanna</Text></TouchableOpacity>
            <Text style={s.detailHeaderTitle}>Vininfo</Text>
            <TouchableOpacity onPress={() => setScreen('log')}><Text style={s.backBtn}>Min logg</Text></TouchableOpacity>
          </View>
          <WineDetailScreen wine={currentWine} onScanAgain={() => setScreen('scanner')} onGoToLog={() => setScreen('log')} />
        </View>
      )}

      {screen === 'log' && (
        <View style={{ flex: 1 }}>
          <View style={s.detailHeader}>
            <TouchableOpacity onPress={() => setScreen('scanner')}><Text style={s.backBtn}>← Skanna</Text></TouchableOpacity>
            <Text style={s.detailHeaderTitle}>Min vinlogg</Text>
            <View style={{ width: 60 }} />
          </View>
          <WineLogScreen onScan={() => setScreen('scanner')} />
        </View>
      )}

      <View style={s.tabBar}>
        <TouchableOpacity style={s.tab} onPress={() => setScreen('scanner')}>
          <Text style={s.tabIcon}>📷</Text>
          <Text style={[s.tabLabel, screen === 'scanner' && s.tabActive]}>Skanna</Text>
        </TouchableOpacity>
        <TouchableOpacity style={s.tab} onPress={() => setScreen('log')}>
          <Text style={s.tabIcon}>📒</Text>
          <Text style={[s.tabLabel, screen === 'log' && s.tabActive]}>Min logg</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

// ─── Stilar ───────────────────────────────────────────────────────────────────

const C = 26, CW = 4;

const s = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24, backgroundColor: '#1a0a0e' },
  permTitle: { color: '#fff', fontSize: 22, fontWeight: '700', marginBottom: 12, textAlign: 'center' },
  permText: { color: 'rgba(255,255,255,0.7)', fontSize: 15, textAlign: 'center', marginBottom: 28, lineHeight: 22 },
  btn: { backgroundColor: '#6B2737', paddingHorizontal: 28, paddingVertical: 13, borderRadius: 12, alignItems: 'center' },
  btnText: { color: '#fff', fontSize: 15, fontWeight: '600' },
  scanOverlay: { flex: 1, justifyContent: 'space-between' },
  scanTop: { alignItems: 'center', paddingTop: 50, paddingBottom: 20, backgroundColor: 'rgba(0,0,0,0.55)', paddingHorizontal: 20 },
  scanTitle: { color: '#fff', fontSize: 26, fontWeight: '700' },
  scanHint: { color: 'rgba(255,255,255,0.8)', fontSize: 13, marginTop: 5, textAlign: 'center' },
  scanBox: { width: 260, height: 160, alignSelf: 'center' },
  corner: { position: 'absolute', width: C, height: C, borderColor: '#fff' },
  tl: { top: 0, left: 0, borderTopWidth: CW, borderLeftWidth: CW },
  tr: { top: 0, right: 0, borderTopWidth: CW, borderRightWidth: CW },
  bl: { bottom: 0, left: 0, borderBottomWidth: CW, borderLeftWidth: CW },
  br: { bottom: 0, right: 0, borderBottomWidth: CW, borderRightWidth: CW },
  scanLoading: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.6)', alignItems: 'center', justifyContent: 'center', borderRadius: 4 },
  scanBottom: { alignItems: 'center', paddingBottom: 30, paddingTop: 20, backgroundColor: 'rgba(0,0,0,0.55)' },
  detailBg: { flex: 1, backgroundColor: '#f5f0eb' },
  detailHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', backgroundColor: '#6B2737', paddingHorizontal: 16, paddingVertical: 12 },
  detailHeaderTitle: { color: '#fff', fontSize: 16, fontWeight: '700' },
  backBtn: { color: '#fff', fontSize: 14 },
  wineName: { fontSize: 24, fontWeight: '700', color: '#1a0a0e', lineHeight: 30 },
  producer: { fontSize: 16, color: '#555', marginTop: 4 },
  card: { backgroundColor: '#fff', borderRadius: 14, padding: 16, marginBottom: 12, shadowColor: '#000', shadowOpacity: 0.06, shadowRadius: 8, elevation: 2 },
  cardTitle: { fontSize: 12, fontWeight: '700', color: '#6B2737', textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 10 },
  sourceBadge: { backgroundColor: '#e8f5e9', borderRadius: 8, paddingHorizontal: 10, paddingVertical: 4, alignSelf: 'flex-start', marginBottom: 10 },
  sourceBadgeText: { color: '#2d7a3a', fontSize: 12, fontWeight: '700' },
  tag: { backgroundColor: '#f0ebe6', borderRadius: 5, paddingHorizontal: 7, paddingVertical: 2, fontSize: 12, color: '#555' },
  logCard: { backgroundColor: '#fff', borderRadius: 14, padding: 14, marginBottom: 12, shadowColor: '#000', shadowOpacity: 0.06, shadowRadius: 8, elevation: 2 },
  editBtn: { backgroundColor: '#f0ebe6', paddingHorizontal: 14, paddingVertical: 7, borderRadius: 8 },
  modalLabel: { fontSize: 12, color: '#888', marginBottom: 6, marginTop: 8, fontWeight: '600', textTransform: 'uppercase' },
  input: { borderWidth: 1, borderColor: '#e0d8d0', borderRadius: 10, padding: 12, fontSize: 15, color: '#1a0a0e' },
  tabBar: { flexDirection: 'row', backgroundColor: '#fff', borderTopWidth: 1, borderTopColor: '#e8e0d8', paddingBottom: 4 },
  tab: { flex: 1, alignItems: 'center', paddingTop: 8, paddingBottom: 4 },
  tabIcon: { fontSize: 20 },
  tabLabel: { fontSize: 11, color: '#aaa', marginTop: 2, fontWeight: '600' },
  tabActive: { color: '#6B2737' },
});
