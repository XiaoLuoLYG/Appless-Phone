# AIPhone 社交通知权限准备清单

## 要准备的权限

### system_core / PC 路线

这台 HPR-W72 / OpenHarmony 7 PC 设备上，普通 `ohos.permission.SUBSCRIBE_NOTIFICATION` 没有出现在运行时权限表里。AIPhone 现在已经按 system_core 包准备通知订阅声明，签名 Profile 需要承载以下权限：

- `ohos.permission.SUBSCRIBE_NOTIFICATION`
- `ohos.permission.NOTIFICATION_SYSTEM_SUBSCRIBER`
- `ohos.permission.NOTIFICATION_CONTROLLER`
- `ohos.permission.NOTIFICATION_AGENT_CONTROLLER`
- `ohos.permission.SUBSCRIBE_NOTIFICATION_WINDOW_STATE`

其中 `ohos.permission.NOTIFICATION_SYSTEM_SUBSCRIBER` 是当前 PC 设备上最关键的系统通知订阅权限；`ohos.permission.NOTIFICATION_CONTROLLER` 和 `ohos.permission.NOTIFICATION_AGENT_CONTROLLER` 用于系统通知控制链路；`ohos.permission.SUBSCRIBE_NOTIFICATION_WINDOW_STATE` 用于通知窗口状态订阅能力。最终是否授予以系统签名、Profile 和设备权限表共同为准。

签名侧还需要确保：

- 包名：`com.example.aiphonedemo`
- 应用权限级别：`system_core`
- Profile/ACL 包含上面的 system/system_core 权限
- 设备 UDID 已加入调试 Profile
- `build-profile.json5` 的 `material.profile` 指向你提供的 system_core `.p7b`
- 如果证书或 p12 也更换，`material.certpath` 和 `material.storeFile` 同步指向对应文件

本机 DevEco SDK 还需要认识 `ohos.permission.NOTIFICATION_SYSTEM_SUBSCRIBER`，否则 Hvigor 会在 manifest 校验阶段报 `Permission ... does not exist`。当前工程已提供可复现补丁脚本：

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  node scripts/patch-deveco-system-notification-permission.mjs
```

脚本会补：

- `openharmony/toolchains/lib/PermissionDefinitions.json`
- `openharmony/previewer/common/resources/module.json`
- `openharmony/ets/api/permissions.d.ts`
- `openharmony/js/api/permissions.d.ts`

并为每个文件生成一次 `.aiphone-backup` 备份。DevEco SDK 升级后如果权限表被覆盖，重新执行一次即可。

## 项目侧已准备

- `entry/src/main/module.json5` 已声明 system_core 通知订阅权限组合。
- `entry/src/main/module.json5` 已注册 `NotificationSubscriberExtAbility`，类型为 `notificationSubscriber`。
- `NotificationSubscriberExtAbility` 已声明通知订阅扩展需要的系统权限。
- `entry/src/main/ets/extensionability/NotificationSubscriberExtAbility.ets` 会接收系统通知回调，记录 `[AIPhone][SocialNotificationReceived]` 日志。
- `entry/src/main/ets/model/SocialNotificationArchive.ets` 只归档识别为微信、且标题和正文都非空的真实通知；已兼容 `content.title/text` 与嵌套 `request.content.normal.title/text` 两类结构。
- AIPhone 社交页不会展示模拟消息；如果没有真实通知回调或辅助捕获，会显示不可用状态。

### 普通 ACL 路线

如果后续换到手机/平板且设备运行时支持普通通知订阅，可以只申请：

- 权限名：`ohos.permission.SUBSCRIBE_NOTIFICATION`
- 权限用途：允许应用读取系统或已安装应用发布的通知。
- 权限级别：以官方受限开放权限列表为准。
- 授权方式：通常需要 ACL/Profile 加系统授权。
- API 要求：通知订阅扩展能力从 API 22 开始支持。

## AppGallery Connect 申请步骤

普通 ACL 权限可在 AppGallery Connect 申请；system_core 权限通常不在普通开发者后台权限列表中，需要走系统应用/设备厂商签名 Profile 流程。

1. 登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)。
2. 进入“开发与服务”，选择 AIPhoneDemo 对应项目和应用/元服务。
3. 确认应用包名与工程一致：`com.example.aiphonedemo`。
4. 进入“项目设置 > ACL权限”，点击申请 ACL 权限。
5. 在权限搜索框里搜索并选择：`ohos.permission.SUBSCRIBE_NOTIFICATION`。
6. 权限使用场景建议填写：

   `AIPhone 社交收件箱需要在用户主动授权后读取本机微信通知，用于在 AIPhone 内展示真实新消息并支持用户输入原文转发回复。消息仅保存在设备本地短期缓存，不上传服务器，不生成模拟消息，不读取未授权应用通知。`

7. 审核通过后，重新创建或更新调试 Profile。
8. 在调试 Profile 的“申请权限”里选择“受限 ACL 权限（HarmonyOS API9及以上）”，确保已获批的 `ohos.permission.SUBSCRIBE_NOTIFICATION` 被加入 Profile。
9. 如果是调试 Profile，添加当前设备 UDID 后下载新的 `.p7b`。
10. 在 DevEco Studio 的签名配置中替换为新的 `.p7b` Profile，并重新打包安装。

发布 Profile 也要重复同样的 ACL 权限加入动作，否则发布包会没有该权限。

## 设备侧授权步骤

PC system_core 路线不依赖普通设置页里的“通知读取授权”入口。安装带 system_core Profile 的 HAP 后，直接用真实微信新消息验证通知订阅回调。

普通 ACL 路线如果设备存在授权入口，可按下面做：

1. 安装带新 Profile 签名的 HAP。
2. 打开 AIPhone，点击顶部“社交”。
3. 在系统通知读取授权页里开启 AIPhone。
4. 在“已获取的本机通知”应用列表里开启微信。
5. 确认微信系统通知和消息详情预览已开启，否则 AIPhone 只能拿到系统实际展示的隐藏文案。
6. 用另一台设备或另一个微信账号发送真实新消息。
7. 回到 AIPhone 社交页，确认消息来源显示为“通知中心”。

## 验证命令

```bash
hdc list targets
hdc -t "$TARGET" shell bm get --udid
hdc -t "$TARGET" shell bm dump -n com.example.aiphonedemo | rg "appPrivilegeLevel|NOTIFICATION|SUBSCRIBE|notificationSubscriber"
hdc -t "$TARGET" shell atm dump -t -b com.example.aiphonedemo | rg "NOTIFICATION|SUBSCRIBE"
hdc -t "$TARGET" shell aa force-stop com.example.aiphonedemo
hdc -t "$TARGET" shell aa start -a EntryAbility -b com.example.aiphonedemo
hdc -t "$TARGET" hilog | rg "AIPhone.*SocialNotification|NotificationSubscriber"
```

关键日志：

- `[AIPhone][SocialNotificationReceived]`：扩展能力收到了系统通知。
- `[AIPhone][SocialNotificationArchive]`：通知被识别为微信并写入本地短缓存。
- `[AIPhone][SocialNotificationSkip]`：通知不是微信，或标题/正文不足，没有进入收件箱。
- `[AIPhone][SocialNotificationSettingsError]`：ACL/Profile/设备能力不足，系统拒绝打开授权页。

## 官方参考

- [通知订阅扩展能力概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/notification-subscriber-extension-ability)
- [通知订阅扩展能力开发步骤](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ion-subscriber-extension-ability-development-steps)
- [受限开放权限列表](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/restricted-permissions)
- [申请 ACL 权限](https://developer.huawei.com/consumer/cn/doc/app/agc-help-apply-acl-0000002394212138)
- [申请调试 Profile](https://developer.huawei.com/consumer/cn/doc/app/agc-help-debug-profile-0000002248181278)
