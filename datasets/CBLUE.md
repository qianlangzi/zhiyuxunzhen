# CBLUE 数据集来源说明

> 本文档记录本项目所使用的 **CBLUE** 数据集的官方来源、许可证与引用方式，便于合规使用与溯源。

## 1. 数据集简介
CBLUE（**C**hinese **B**iomedical **L**anguage **U**nderstanding **E**valuation，中文生物医学语言理解评测基准）由真实医疗场景数据构建，包含 8 个中文医疗自然语言理解（NLU）任务，并提供基线模型与在线评测平台，用于评估、比较和分析医疗 AI 模型的效果。

## 2. 官方来源
- GitHub 仓库：https://github.com/CBLUEbenchmark/CBLUE
- 数据集下载（阿里云天池）：https://tianchi.aliyun.com/dataset/dataDetail?dataId=95414
- 中文说明文档：https://github.com/CBLUEbenchmark/CBLUE/blob/main/README_ZH.md

## 3. 许可证
- 代码仓库 LICENSE：**Apache License 2.0**
- 数据集本体通过阿里云天池平台分发，使用前需在天池平台同意其数据集使用协议（通常需注册账号）。请遵守天池平台的数据使用条款，仅用于研究 / 评测目的。

## 4. 包含的任务 / 子数据集（共 8 个）
| 子数据集 | 任务类型 | 说明 |
|----------|----------|------|
| CMeEE | 命名实体识别 (NER) | 医疗文本实体抽取 |
| CMeIE | 关系抽取 (Relation Extraction) | 医疗实体关系抽取 |
| CHIP-CDN | 诊断标准化 (Diagnosis Normalization) | 疾病术语归一化 |
| CHIP-STS | 句子相似度 | 医疗句子语义相似度 |
| CHIP-CTC | 句子分类 | 临床试验文本分类 |
| KUAKE-QIC | 意图分类 | 医疗查询意图识别 |
| KUAKE-QQR | 自然语言推理 | 查询-查询相关性 |
| KUAKE-QTR | 自然语言推理 | 查询-标题相关性 |

## 5. 引用方式
```bibtex
@inproceedings{zhang-etal-2022-cblue,
  title     = "{CBLUE}: A {C}hinese Biomedical Language Understanding Evaluation Benchmark",
  author    = "Zhang, Ningyu and Chen, Mosha and Bi, Zhen and others",
  booktitle = "Proceedings of the 60th Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers)",
  month     = may,
  year      = "2022",
  address   = "Dublin, Ireland",
  publisher = "Association for Computational Linguistics",
  url       = "https://aclanthology.org/2022.acl-long.544",
  pages     = "7888--7915"
}
```
- 论文链接：https://aclanthology.org/2022.acl-long.544
- arXiv 预印本：https://arxiv.org/abs/2106.08087

## 6. 在本项目中的说明
（请在此补充本项目如何使用 CBLUE 数据，例如数据存放路径、预处理 / 清洗方式、对应的训练或评测脚本等。）
