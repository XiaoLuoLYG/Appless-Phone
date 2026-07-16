import connection from '@ohos.net.connection';

export interface ComposioNetworkLease {
  previousNetwork: connection.NetHandle | null;
  bound: boolean;
  release: () => void;
}

let networkQueue: Promise<void> = Promise.resolve();

function noOp(): void {
}

async function physicalNetwork(): Promise<connection.NetHandle | null> {
  const nets = await connection.getAllNets();
  let cellular: connection.NetHandle | null = null;
  for (let index = 0; index < nets.length; index++) {
    const capabilities = await connection.getNetCapabilities(nets[index]);
    const networkCaps = capabilities.networkCap ?? [];
    if (networkCaps.indexOf(connection.NetCap.NET_CAPABILITY_INTERNET) < 0 ||
      networkCaps.indexOf(connection.NetCap.NET_CAPABILITY_NOT_VPN) < 0) {
      continue;
    }
    if (capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) >= 0) {
      return nets[index];
    }
    if (capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_CELLULAR) >= 0) {
      cellular = nets[index];
    }
  }
  return cellular;
}

export async function bindComposioPhysicalNetwork(): Promise<ComposioNetworkLease> {
  let release: () => void = noOp;
  const turn = new Promise<void>((resolve: () => void) => {
    release = resolve;
  });
  const previousTurn = networkQueue;
  networkQueue = turn;
  await previousTurn;
  try {
    const network = await physicalNetwork();
    const previousNetwork = await connection.getAppNet();
    if (network === null) {
      return { previousNetwork: previousNetwork, bound: false, release: release };
    }
    await connection.setAppNet(network);
    return { previousNetwork: previousNetwork, bound: true, release: release };
  } catch (error) {
    release();
    throw new Error(error instanceof Error ? error.message : JSON.stringify(error));
  }
}

export async function restoreComposioNetwork(lease: ComposioNetworkLease): Promise<void> {
  try {
    if (lease.bound && lease.previousNetwork !== null) {
      await connection.setAppNet(lease.previousNetwork);
    }
  } finally {
    lease.release();
  }
}
