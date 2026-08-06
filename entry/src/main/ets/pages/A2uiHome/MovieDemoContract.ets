export const MOVIE_DEMO_RAWFILE: string = 'movie_entertainment.html';
export const MOVIE_DEMO_MARKER: string = '电影 Anything OS';

export function isTrustedMovieSourceUrl(url: string): boolean {
  return url.startsWith('https://');
}
