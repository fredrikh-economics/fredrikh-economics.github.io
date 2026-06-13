import AsyncStorage from '@react-native-async-storage/async-storage';

const LOG_KEY = 'wine_log';

export async function getWineLog() {
  const json = await AsyncStorage.getItem(LOG_KEY);
  return json ? JSON.parse(json) : [];
}

export async function addToWineLog(wine) {
  const log = await getWineLog();
  const entry = {
    ...wine,
    id: Date.now().toString(),
    dateTasted: new Date().toISOString(),
    rating: null,
    notes: '',
  };
  log.unshift(entry);
  await AsyncStorage.setItem(LOG_KEY, JSON.stringify(log));
  return entry;
}

export async function updateWineEntry(id, updates) {
  const log = await getWineLog();
  const index = log.findIndex(w => w.id === id);
  if (index !== -1) {
    log[index] = { ...log[index], ...updates };
    await AsyncStorage.setItem(LOG_KEY, JSON.stringify(log));
  }
}

export async function deleteWineEntry(id) {
  const log = await getWineLog();
  const updated = log.filter(w => w.id !== id);
  await AsyncStorage.setItem(LOG_KEY, JSON.stringify(updated));
}
