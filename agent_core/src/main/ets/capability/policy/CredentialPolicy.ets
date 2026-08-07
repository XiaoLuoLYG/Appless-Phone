import { ToolSpec } from '../contracts/ToolSpec';

export class CredentialPolicy {
  hasRequiredReferences(spec: ToolSpec): boolean {
    return !spec.credentialRequirements.some((requirement): boolean =>
      requirement.required && requirement.reference.trim().length === 0
    );
  }
}
