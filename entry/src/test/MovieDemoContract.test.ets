import { describe, it, expect } from '@ohos/hypium';
import {
  MOVIE_DEMO_MARKER,
  MOVIE_DEMO_RAWFILE,
  isTrustedMovieSourceUrl
} from '../main/ets/pages/A2uiHome/MovieDemoContract';

export default function movieDemoContractTest() {
  describe('movieDemoContract', () => {
    it('keeps the movie asset and visible marker stable', 0, () => {
      expect(MOVIE_DEMO_RAWFILE).assertEqual('movie_entertainment.html');
      expect(MOVIE_DEMO_MARKER).assertEqual('电影 Anything OS');
    });

    it('allows only HTTPS source links', 0, () => {
      expect(isTrustedMovieSourceUrl('https://spidermanbrandnewday.movie/trailer/')).assertTrue();
      expect(isTrustedMovieSourceUrl('http://example.com/video')).assertFalse();
      expect(isTrustedMovieSourceUrl('javascript:alert(1)')).assertFalse();
    });
  });
}
