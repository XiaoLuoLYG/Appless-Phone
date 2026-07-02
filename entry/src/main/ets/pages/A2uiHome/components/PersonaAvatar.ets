export function personaAvatarResource(avatarKey: string): Resource {
  if (avatarKey === 'food') {
    return $r('app.media.persona_avatar_food');
  }
  if (avatarKey === 'travel') {
    return $r('app.media.persona_avatar_travel');
  }
  if (avatarKey === 'work') {
    return $r('app.media.persona_avatar_work');
  }
  if (avatarKey === 'entertainment') {
    return $r('app.media.persona_avatar_entertainment');
  }
  if (avatarKey === 'game') {
    return $r('app.media.persona_avatar_game');
  }
  if (avatarKey === 'shopping') {
    return $r('app.media.persona_avatar_shopping');
  }
  return $r('app.media.persona_avatar_default');
}
