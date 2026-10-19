# 渝灯AI主流服务预设

核对日期：2026-10-17。F → AI设置 → 下拉选择预设，再填写该平台自己的Key，选择仅本次/保存本机。预设只是配置模板，不承诺免费或账号已开通，不自动调用、不跨平台回退、不读取其他平台的Key。地址与模型可继续手动改写。平台ID变化后可按控制台更新。

| 预设 | 模型ID | 完整接口地址 |
| --- | --- | --- |
| 智谱 | glm-4.7-flash | https://open.bigmodel.cn/api/paas/v4/chat/completions |
| DeepSeek | deepseek-flash | https://api.deepseek.com/chat/completions |
| 千问（北京地域） | qwen-plus | https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions |
| Kimi | kimi-k2.6 | https://api.moonshot.cn/v1/chat/completions |
| 豆包 | doubao-seed-2-0-lite-260215 | https://ark.cn-beijing.volces.com/api/v3/chat/completions |

千问需要地域匹配的API Key，也可替换成业务空间专属域名。豆包需开通模型；使用推理接入点的账号可将模型ID替换为自己的ep-编号。Key不会跟随预设自动转移；切换预设清空尚未保存的密钥输入，只有确认应用才更改当前连接。加密存储仍绑定接口地址。

DeepSeek、豆包预设关闭思考并省略温度，千问预设设置enable_thinking=false，Kimi K2.6关闭思考并使用0.6温度。仅严格匹配预设地址与模型时添加这些参数，不对自定义模型乱加厂商字段。答疑输出仍限制650 tokens。

## 官方依据

- DeepSeek：https://api-docs.deepseek.com/ 与 https://api-docs.deepseek.com/guides/thinking_mode/ （当前官方入门页使用deepseek-flash，未沿用旧deepseek-chat别名）
- 千问：https://help.aliyun.com/zh/model-studio/compatibility-of-openai-with-dashscope （旧北京域名仍可用；建议按账号迁移专属域名）
- Kimi：https://platform.kimi.com/docs/guide/kimi-k2-6-quickstart （非思考温度限定0.6）
- 豆包：https://docs.volcengine.com/docs/ark/deep-thinking?lang=en 与 https://api.volcengine.com/api-explorer/?action=ChatCompletions&serviceCode=ark&version=2024-01-01

## 验证边界

test_ai_presets_v3验证预设切换、清除输入、不自动请求、应用后payload、各平台字段和基础视口布局。没有其他平台真实Key，未发起这些平台的真实付费请求；不能将配置测试称为全部平台真实联调成功。已有智谱真实接入测试不受影响。
