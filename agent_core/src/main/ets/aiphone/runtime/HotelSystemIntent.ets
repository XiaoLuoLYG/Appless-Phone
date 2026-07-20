import { buildSystemFoodNavigationUri } from './FoodNavigation';
import {
  compactHotelDialPhone,
  HotelNavigateArgs,
  validHotelNavigateArgs
} from './HotelActions';

export function hotelDialUri(dialPhone: string): string {
  const compact = compactHotelDialPhone(dialPhone);
  if (compact.length === 0) {
    return '';
  }
  return 'tel:' + compact;
}

export function hotelNavigationUri(args: HotelNavigateArgs): string {
  if (args === null ||
    typeof args !== 'object' ||
    typeof args.name !== 'string' ||
    !validHotelNavigateArgs(args).ok) {
    return '';
  }
  return buildSystemFoodNavigationUri(
    args.longitude.toString() + ',' + args.latitude.toString(),
    '',
    args.name
  );
}
