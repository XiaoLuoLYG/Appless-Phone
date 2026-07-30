import { buildSystemFoodNavigationUri } from './FoodNavigation';
import { HotelNavigateArgs, validHotelNavigateArgs } from './HotelActions';

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
