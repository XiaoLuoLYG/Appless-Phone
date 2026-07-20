import { buildSystemFoodNavigationUri } from './FoodNavigation';
import {
  HotelNavigateArgs,
  validHotelNavigateArgs
} from './HotelActions';

export function hotelDialUri(dialPhone: string): string {
  if (typeof dialPhone !== 'string' ||
    dialPhone.indexOf('\n') >= 0 ||
    dialPhone.indexOf('\r') >= 0) {
    return '';
  }
  const compact = dialPhone.trim().replace(/[ ()-]/g, '');
  if (!/^\+?[0-9]{5,20}$/.test(compact)) {
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
