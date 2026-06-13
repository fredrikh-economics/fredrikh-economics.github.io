const OPEN_FOOD_FACTS_URL = 'https://world.openfoodfacts.org/api/v0/product';

export async function lookupBarcode(barcode) {
  const response = await fetch(`${OPEN_FOOD_FACTS_URL}/${barcode}.json`);
  const data = await response.json();

  if (data.status !== 1) {
    return null;
  }

  const p = data.product;

  return {
    barcode,
    name: p.product_name || p.product_name_sv || p.product_name_en || 'Okänt vin',
    producer: p.brands || '',
    country: p.countries_tags?.[0]?.replace('en:', '') || '',
    region: p.manufacturing_places || '',
    vintage: extractVintage(p.product_name || ''),
    alcohol: p.nutriments?.alcohol || extractAlcohol(p.ingredients_text || ''),
    grapes: extractGrapes(p.ingredients_text || '', p.labels || ''),
    volume: p.quantity || '750 ml',
    image: p.image_url || null,
    categories: p.categories || '',
    labels: p.labels || '',
    storeLink: buildSystembolagetLink(p.product_name || p.brands || barcode),
    rawProduct: p,
  };
}

function extractVintage(name) {
  const match = name.match(/\b(19|20)\d{2}\b/);
  return match ? match[0] : '';
}

function extractAlcohol(ingredients) {
  const match = ingredients.match(/(\d+[.,]\d+)\s*%/);
  return match ? match[1].replace(',', '.') + '%' : '';
}

function extractGrapes(ingredients, labels) {
  const combined = (ingredients + ' ' + labels).toLowerCase();
  const knownGrapes = [
    'cabernet sauvignon', 'merlot', 'pinot noir', 'syrah', 'shiraz',
    'chardonnay', 'sauvignon blanc', 'riesling', 'pinot gris', 'pinot grigio',
    'grenache', 'tempranillo', 'sangiovese', 'nebbiolo', 'barbera',
    'malbec', 'carménère', 'zinfandel', 'gewürztraminer', 'viognier',
    'chenin blanc', 'muscat', 'moscato', 'prosecco', 'champagne',
  ];
  const found = knownGrapes.filter(g => combined.includes(g));
  return found.map(g => g.charAt(0).toUpperCase() + g.slice(1)).join(', ');
}

function buildSystembolagetLink(query) {
  const encoded = encodeURIComponent(query);
  return `https://www.systembolaget.se/sok/?searchQuery=${encoded}`;
}

export function getFoodPairings(wineInfo) {
  const text = (wineInfo.categories + ' ' + wineInfo.name + ' ' + wineInfo.grapes).toLowerCase();

  if (text.includes('champagne') || text.includes('sparkling') || text.includes('mousserande') || text.includes('prosecco')) {
    return {
      pairings: ['Skaldjur', 'Lax', 'Sushi', 'Lätta aptitretare', 'Ostbricka'],
      avoid: ['Tung kött', 'Starkt kryddad mat'],
      temp: '6–8°C',
      occasion: 'Aperitif, fest, nyår',
    };
  }

  if (text.includes('sauvignon blanc') || text.includes('pinot gris') || text.includes('riesling')) {
    return {
      pairings: ['Getost', 'Sallad', 'Fisk', 'Skaldjur', 'Kycklingrätter'],
      avoid: ['Rött kött', 'Tungkryddad mat'],
      temp: '8–10°C',
      occasion: 'Sommarmat, lättare middagar',
    };
  }

  if (text.includes('chardonnay')) {
    return {
      pairings: ['Hummer', 'Grillad fisk', 'Kyckling', 'Creamy pastarätter', 'Brie'],
      avoid: ['Starkt kryddad asiatisk mat'],
      temp: '10–12°C',
      occasion: 'Finmiddag, seafood',
    };
  }

  if (text.includes('pinot noir') || text.includes('bourgogne') || text.includes('burgundy')) {
    return {
      pairings: ['Anka', 'Lax', 'Svamp', 'Mild ost', 'Kalvkött'],
      avoid: ['Stark sås', 'Fet mat'],
      temp: '14–16°C',
      occasion: 'Elegant middag',
    };
  }

  if (text.includes('cabernet') || text.includes('merlot') || text.includes('shiraz') || text.includes('syrah') || text.includes('malbec')) {
    return {
      pairings: ['Grillat nötkött', 'Lamm', 'Vilt', 'Lagrad ost', 'Mörk choklad'],
      avoid: ['Fisk', 'Skaldjur', 'Lätta sallader'],
      temp: '16–18°C',
      occasion: 'Kötträtter, BBQ, höstmiddag',
    };
  }

  if (text.includes('rosé') || text.includes('rose')) {
    return {
      pairings: ['Sallad nicoise', 'Grillad kyckling', 'Lätt pasta', 'Skaldjur'],
      avoid: ['Tung köttgryta'],
      temp: '8–10°C',
      occasion: 'Sommar, utomhusmiddag',
    };
  }

  return {
    pairings: ['Prova till din favoriträtt!'],
    avoid: [],
    temp: '12–16°C',
    occasion: 'Passar de flesta tillfällen',
  };
}
