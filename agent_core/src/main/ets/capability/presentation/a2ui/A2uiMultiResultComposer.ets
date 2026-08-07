import { ToolPresentation } from '../../contracts/PresenterTypes';

interface A2uiMultiResultArtifact {
  surfaceId: string;
  sections: Object[];
}

export class A2uiMultiResultComposer {
  compose(surfaceId: string, presentations: ToolPresentation[]): Object {
    const artifact: A2uiMultiResultArtifact = {
      surfaceId,
      sections: presentations.map((item: ToolPresentation): Object => item.artifact)
    };
    return artifact;
  }
}
