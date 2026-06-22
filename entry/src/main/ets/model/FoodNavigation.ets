export interface FoodNavigationUriDebug {
  uri: string;
  mode: string;
  destination: string;
  origin: string;
  name: string;
}

function cleanCoordinate(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return '';
  }
  const parsed = Number(trimmed);
  if (!Number.isFinite(parsed)) {
    return '';
  }
  return trimmed;
}

export function foodMapsLatLng(location: string): string {
  const parts = location.split(',');
  if (parts.length < 2) {
    return '';
  }
  const longitude = cleanCoordinate(parts[0]);
  const latitude = cleanCoordinate(parts[1]);
  if (longitude.length === 0 || latitude.length === 0) {
    return '';
  }
  return latitude + ',' + longitude;
}

function encodeMapParam(value: string): string {
  return encodeURIComponent(value)
    .replace(/\(/g, '%28')
    .replace(/\)/g, '%29')
    .replace(/'/g, '%27');
}

function cleanDestinationName(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length > 0) {
    return trimmed;
  }
  return '目的地';
}

export function describeSystemFoodNavigationUri(destinationLocation: string, originLocation: string,
  destinationName: string = ''): FoodNavigationUriDebug {
  const destination = foodMapsLatLng(destinationLocation);
  if (destination.length === 0) {
    return { uri: '', mode: 'invalid_destination', destination: '', origin: '', name: '' };
  }
  const origin = foodMapsLatLng(originLocation);
  const name = cleanDestinationName(destinationName);
  return {
    uri: 'petalmaps://poidetail?center=' + destination + '&z=16&marker=' + destination +
      '&name=' + encodeMapParam(name) + '&utm_source=com.example.aiphonedemo',
    mode: 'destination_poi_detail',
    destination: destination,
    origin: origin,
    name: name
  };
}

export function buildSystemFoodNavigationUri(destinationLocation: string, originLocation: string,
  destinationName: string = ''): string {
  return describeSystemFoodNavigationUri(destinationLocation, originLocation, destinationName).uri;
}
