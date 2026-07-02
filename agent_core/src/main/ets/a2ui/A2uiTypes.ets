export interface CreateSurfaceBody {
  surfaceId: string;
  catalogId: string;
}

export interface CreateSurfaceEnvelope {
  version: string;
  createSurface: CreateSurfaceBody;
}

export interface DeleteSurfaceBody {
  surfaceId: string;
}

export interface DeleteSurfaceEnvelope {
  version: string;
  deleteSurface: DeleteSurfaceBody;
}

export interface A2uiComponentDef {
  id: string;
  component: string;
  child?: string;
  children?: string[];
  text?: string;
  variant?: string;
  align?: string;
  justify?: string;
}

export interface UpdateComponentsBody {
  surfaceId: string;
  components: A2uiComponentDef[];
}

export interface UpdateComponentsEnvelope {
  version: string;
  updateComponents: UpdateComponentsBody;
}
