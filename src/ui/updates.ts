/**
 * "A new version is available" — asked of GitHub once per launch, through
 * `updates.rs`, unless switched off in Settings → Advanced. The update button
 * itself is UpdateNotice.tsx.
 */
import { invoke } from '@tauri-apps/api/core';
import { getSetting } from '../metadata/api';

export const UPDATE_CHECK_KEY = 'update_check';

export interface Release {
  version: string;
  url: string;
  /** What this copy updates itself with on a press; null → the download page. */
  install: 'setup' | 'deb' | 'rpm' | 'apk' | null;
}

let asked: Promise<Release | null> | null = null;

/** The newer release, if there is one — asked once and remembered for the launch. */
export function availableUpdate(): Promise<Release | null> {
  asked ??= (async () => {
    if ((await getSetting(UPDATE_CHECK_KEY).catch(() => null)) === 'off') return null;
    return invoke<Release | null>('latest_release').catch(() => null);
  })();
  return asked;
}
