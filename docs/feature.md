# Feature

* 新增下述功能；
* 执行时请从知识库中获取HarmonyOS的最佳实践；
* 对于无法解决的问题，请标记后跳过，并注明原因。

## 添加路由参数识别

* 参数：wl_nav_style
  * 描述：添加路由参数识别, 控制页面顶部导航栏样式，不传时默认显示
  * 参数值：
    * 0: 隐藏系统导航
    * 1: 导航栏透明，只显示返回按钮
  * 导入网址示例：https://hlovez.life?wl_nav_style=0

* 参数：wl_nav_title
  * 描述：添加路由参数识别, 控制页面顶部导航栏标题，不传时默认显示
  * 导入网址示例：https://hlovez.life?wl_nav_title=这是一个标题
  * 注意：
    * 优先级低于参数wl_nav_style
    * 优先级高于导入时设置的标题

## jsbridge注册

* 请先调研鸿蒙系统如何使用jsbridge，js如何与h5交互，提供一下方法供H5使用

* 添加jsbridge注册方法；
* 提供jsbridge调用方法；

方法列表:

参数返回值均为JSON格式

* 获取应用信息获取
  * 参数：无
  * 返回值：
    * status: 状态
    * data:
      * appName: 应用名称
      * appVersion: 应用版本
      * appVersionName: 应用版本名称
      * internet: 网络状态
      * deviceBrand: 设备品牌
      * deviceModel: 设备型号

* 修改导航样式
  * 参数：
    * style: 样式
    * title: 标题
  * 返回值：无

* 调用系统分享
  * 参数：
    * title: 分享标题
    * content: 分享内容
    * image: 分享图片
    * url: 分享链接
    * type: 分享类型
  * 返回值：
    * status: 状态
    * data:
      * platform: 分享平台

* 调用系统图片选择
  * 参数：
    * type: 图片类型，png/jpg
    * count: 图片数量，默认1，最大9
    * limit: 图片大小限制[0MB,5MB], 单位MB
  * 返回值：
    * status: 状态
    * data<Array>:
      * path: 文件路径
      * name: 文件名称
      * size: 文件大小
      * base64: 文件base64
  * 注意：
    * limit参数可选，默认为3MB
    * type参数可选，默认支持MIME Type种的图片类型，

* 调用震动
  * 参数(具体参数请根据系统提供能力确认)：
    * type: 震动类型
    * duration: 震动时长，单位毫秒，默认100ms，最大1000ms
    * interval: 震动间隔, 单位毫秒，默认100ms，最大1000ms
    * count: 震动次数，默认1，最大5
  * 返回值：
    * status: 状态
    * data: 无

