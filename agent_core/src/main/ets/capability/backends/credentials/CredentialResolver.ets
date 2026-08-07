export interface CredentialResolution {
  available: boolean;
  reference: string;
  accountHint: string;
  reason: string;
}

export interface CredentialResolver {
  resolve(mode: string, reference: string): CredentialResolution;
}
