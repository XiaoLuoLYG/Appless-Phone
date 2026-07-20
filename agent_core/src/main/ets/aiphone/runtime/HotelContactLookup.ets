import { HotelContact, HotelSearchItem } from './HotelToolTypes';
import { compactHotelDialPhone } from './HotelActions';

const EARTH_RADIUS_METERS: number = 6371000;
const MAX_MATCH_DISTANCE_METERS: number = 300;
const MIN_ADDRESS_IDENTITY_LENGTH: number = 6;

export interface HotelContactCandidate {
  providerPlaceId: string;
  displayName: string;
  formattedAddress: string;
  latitude: number | null;
  longitude: number | null;
}

export interface HotelContactDetails extends HotelContactCandidate {
  nationalPhoneNumber: string;
  internationalPhoneNumber: string;
}

export interface HotelContactMatchResult {
  candidate: HotelContactCandidate | null;
  warning: string;
}

export interface HotelContactLookupResult {
  contact: HotelContact | null;
  warning: string;
  sourceReceived: boolean;
}

function normalizedIdentity(value: string): string {
  return value.trim().toLowerCase().replace(/[\s\-_,.，。·•:：;；'"“”‘’（）()\[\]{}【】/\\&＆]/g, '');
}

function validCoordinate(latitude: number | null, longitude: number | null): boolean {
  return latitude !== null && longitude !== null && Number.isFinite(latitude) && Number.isFinite(longitude) &&
    latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
}

function radians(degrees: number): number {
  return degrees * Math.PI / 180;
}

function distanceMeters(hotel: HotelSearchItem, candidate: HotelContactCandidate): number | null {
  if (!validCoordinate(hotel.latitude, hotel.longitude) || !validCoordinate(candidate.latitude, candidate.longitude)) {
    return null;
  }
  const hotelLatitude = hotel.latitude as number;
  const hotelLongitude = hotel.longitude as number;
  const candidateLatitude = candidate.latitude as number;
  const candidateLongitude = candidate.longitude as number;
  const latitudeDelta = radians(candidateLatitude - hotelLatitude);
  const longitudeDelta = radians(candidateLongitude - hotelLongitude);
  const latitudeA = radians(hotelLatitude);
  const latitudeB = radians(candidateLatitude);
  const haversine = Math.sin(latitudeDelta / 2) * Math.sin(latitudeDelta / 2) +
    Math.cos(latitudeA) * Math.cos(latitudeB) *
    Math.sin(longitudeDelta / 2) * Math.sin(longitudeDelta / 2);
  return 2 * EARTH_RADIUS_METERS * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
}

function exactHotelName(hotel: HotelSearchItem, candidate: HotelContactCandidate): boolean {
  const candidateName = normalizedIdentity(candidate.displayName);
  if (candidateName.length === 0) {
    return false;
  }
  const chineseName = normalizedIdentity(hotel.name);
  const englishName = normalizedIdentity(hotel.nameEn);
  return (chineseName.length > 0 && candidateName === chineseName) ||
    (englishName.length > 0 && candidateName === englishName);
}

function containedHotelAddress(hotel: HotelSearchItem, candidate: HotelContactCandidate): boolean {
  const hotelAddress = normalizedIdentity(hotel.address);
  const candidateAddress = normalizedIdentity(candidate.formattedAddress);
  if (hotelAddress.length < MIN_ADDRESS_IDENTITY_LENGTH || candidateAddress.length < MIN_ADDRESS_IDENTITY_LENGTH) {
    return false;
  }
  return hotelAddress.indexOf(candidateAddress) >= 0 || candidateAddress.indexOf(hotelAddress) >= 0;
}

function qualifyingCandidate(hotel: HotelSearchItem, candidate: HotelContactCandidate): boolean {
  if (candidate.providerPlaceId.trim().length === 0 || !exactHotelName(hotel, candidate)) {
    return false;
  }
  const distance = distanceMeters(hotel, candidate);
  return (distance !== null && distance <= MAX_MATCH_DISTANCE_METERS) || containedHotelAddress(hotel, candidate);
}

export function selectHotelContactCandidate(
  hotel: HotelSearchItem,
  candidates: HotelContactCandidate[]
): HotelContactMatchResult {
  let selected: HotelContactCandidate | null = null;
  let qualifyingCount = 0;
  for (let index = 0; index < candidates.length; index++) {
    if (qualifyingCandidate(hotel, candidates[index])) {
      selected = candidates[index];
      qualifyingCount += 1;
    }
  }
  if (qualifyingCount === 1) {
    return { candidate: selected, warning: '' };
  }
  if (qualifyingCount > 1) {
    return { candidate: null, warning: 'Google Places returned multiple verified hotel identity matches.' };
  }
  return { candidate: null, warning: 'Google Places returned no unique verified hotel identity match.' };
}

function trimAsciiPhoneDisplay(value: string): string {
  return value.replace(/^ +| +$/g, '');
}

export function hotelContactFromDetails(
  details: HotelContactDetails,
  expectedPlaceId: string
): HotelContact | null {
  const placeId = details.providerPlaceId.trim();
  if (placeId.length === 0 || placeId !== expectedPlaceId.trim()) {
    return null;
  }
  const internationalDisplay = trimAsciiPhoneDisplay(details.internationalPhoneNumber);
  const internationalDial = compactHotelDialPhone(internationalDisplay);
  const nationalDisplay = trimAsciiPhoneDisplay(details.nationalPhoneNumber);
  const nationalDial = compactHotelDialPhone(nationalDisplay);
  if (internationalDial.length > 0) {
    return {
      displayPhone: internationalDisplay,
      dialPhone: internationalDial,
      provider: 'Google Places',
      providerPlaceId: placeId
    };
  }
  if (nationalDial.length > 0) {
    return {
      displayPhone: nationalDisplay,
      dialPhone: nationalDial,
      provider: 'Google Places',
      providerPlaceId: placeId
    };
  }
  return null;
}
