# Prompt Versioning

提示词是发布物，不在路由函数中拼接。当前模板位于 `app/prompts/templates.py`，每次修改必须：

1. 更新模板中的版本常量或变更记录。
2. 为正常回答、敏感输入、无 RAG、模型超时各保留一条回归样例。
3. 在日志和 Langfuse trace 中记录 prompt 名称与版本，不记录完整患者隐私。
4. 先在测试环境验证 JSON schema、引用格式和安全策略，再发布到生产。

推荐命名：`sp.v1`、`mentor.v1`、`reviewer.v1`。版本只前进不复用；回滚通过配置选择旧版本。
