#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const sdkHome = process.env.DEVECO_SDK_HOME || '/Applications/DevEco-Studio.app/Contents/sdk';
const defaultSdkHome = path.join(sdkHome, 'default');
const permissionJsonPath = path.join(defaultSdkHome, 'openharmony', 'toolchains', 'lib', 'PermissionDefinitions.json');
const etsPermissionsPath = path.join(defaultSdkHome, 'openharmony', 'ets', 'api', 'permissions.d.ts');
const jsPermissionsPath = path.join(defaultSdkHome, 'openharmony', 'js', 'api', 'permissions.d.ts');
const previewerModulePath = path.join(defaultSdkHome, 'openharmony', 'previewer', 'common', 'resources', 'module.json');
const permissionName = 'ohos.permission.NOTIFICATION_SYSTEM_SUBSCRIBER';

const permissionDefinition = {
  name: permissionName,
  grantMode: 'system_grant',
  availableLevel: 'system_core',
  availableType: 'SYSTEM',
  since: 22,
  deprecated: '',
  provisionEnable: true,
  distributedSceneEnable: false
};

function assertFile(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing DevEco SDK file: ${filePath}`);
  }
}

function backupOnce(filePath) {
  const backupPath = `${filePath}.aiphone-backup`;
  if (!fs.existsSync(backupPath)) {
    fs.copyFileSync(filePath, backupPath);
  }
}

function patchPermissionDefinitions() {
  assertFile(permissionJsonPath);
  const raw = fs.readFileSync(permissionJsonPath, 'utf8');
  const parsed = JSON.parse(raw);
  const permissions = parsed.definePermissions;
  if (!Array.isArray(permissions)) {
    throw new Error('PermissionDefinitions.json does not contain definePermissions array');
  }
  if (permissions.some((item) => item && item.name === permissionName)) {
    console.log(`${permissionName} already exists in PermissionDefinitions.json`);
    return;
  }
  const controllerIndex = permissions.findIndex((item) => item && item.name === 'ohos.permission.NOTIFICATION_CONTROLLER');
  const insertIndex = controllerIndex >= 0 ? controllerIndex + 1 : permissions.length;
  backupOnce(permissionJsonPath);
  permissions.splice(insertIndex, 0, permissionDefinition);
  fs.writeFileSync(permissionJsonPath, `${JSON.stringify(parsed, null, 4)}\n`);
  console.log(`Patched ${permissionJsonPath}`);
}

function patchPreviewerModule() {
  assertFile(previewerModulePath);
  const raw = fs.readFileSync(previewerModulePath, 'utf8');
  const parsed = JSON.parse(raw);
  const permissions = parsed.module && parsed.module.definePermissions;
  if (!Array.isArray(permissions)) {
    throw new Error('previewer module.json does not contain module.definePermissions array');
  }
  if (permissions.some((item) => item && item.name === permissionName)) {
    console.log(`${permissionName} already exists in previewer module.json`);
    return;
  }
  const controllerIndex = permissions.findIndex((item) => item && item.name === 'ohos.permission.NOTIFICATION_CONTROLLER');
  const insertIndex = controllerIndex >= 0 ? controllerIndex + 1 : permissions.length;
  backupOnce(previewerModulePath);
  permissions.splice(insertIndex, 0, permissionDefinition);
  fs.writeFileSync(previewerModulePath, `${JSON.stringify(parsed)}\n`);
  console.log(`Patched ${previewerModulePath}`);
}

function patchPermissionsType(filePath) {
  assertFile(filePath);
  const raw = fs.readFileSync(filePath, 'utf8');
  if (raw.includes(`'${permissionName}'`)) {
    console.log(`${permissionName} already exists in ${filePath}`);
    return;
  }
  const marker = " | 'ohos.permission.NOTIFICATION_CONTROLLER'";
  const markerIndex = raw.indexOf(marker);
  if (markerIndex < 0) {
    throw new Error(`Could not find insertion marker in ${filePath}`);
  }
  const insertAt = raw.indexOf('\n', markerIndex);
  if (insertAt < 0) {
    throw new Error(`Could not find insertion line ending in ${filePath}`);
  }
  const patch = `\n/**\n * @since 22\n */\n | '${permissionName}'`;
  backupOnce(filePath);
  fs.writeFileSync(filePath, `${raw.slice(0, insertAt)}${patch}${raw.slice(insertAt)}`);
  console.log(`Patched ${filePath}`);
}

patchPermissionDefinitions();
patchPreviewerModule();
patchPermissionsType(etsPermissionsPath);
patchPermissionsType(jsPermissionsPath);
