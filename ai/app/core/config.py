"""AI 中台全局配置"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # 服务
    app_name: str = "zhiyu-ai"
    app_version: str = "0.1.0"

    # 科大讯飞星火(文本 / 多模态)
    spark_app_id: str = ""
    spark_api_key: str = ""
    spark_api_secret: str = ""
    spark_vision_app_id: str = ""
    spark_vision_api_key: str = ""
    spark_vision_api_secret: str = ""

    # Milvus
    milvus_host: str = "milvus"
    milvus_port: int = 19530

    # 业务中台回调地址(容器内网络)
    backend_callback_url: str = "http://backend:8080"


settings = Settings()
