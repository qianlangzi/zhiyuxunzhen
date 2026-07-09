# CMB 数据集来源说明

> 本文档记录本项目所使用的 **CMB** 数据集的官方来源、许可证与引用方式，便于合规使用与溯源。

## 1. 数据集简介
CMB（**C**hinese **M**edical **B**enchmark，中文医疗综合评测基准）是一个面向中文医疗场景的综合评测数据集，涵盖多层次医学知识考核（CMB-Exam）与复杂临床问诊案例（CMB-Clin），用于评估大语言模型的医疗知识与临床推理能力。

## 2. 官方来源
- GitHub 仓库：https://github.com/FreedomIntelligence/CMB
- HuggingFace 数据集：https://huggingface.co/datasets/FreedomIntelligence/CMB
- 官方主页 / 榜单：https://cmedbenchmark.llmzoo.com/

## 3. 许可证
- 数据集 LICENSE：**Apache License 2.0**（HuggingFace 数据集卡 `license: apache-2.0`）
- 可自由用于研究、评测与二次分发，请遵循 Apache-2.0 的署名与声明要求。

## 4. 数据集组成
| 子集 | 说明 | 规模 |
|------|------|------|
| CMB-Exam | 综合性医学知识考核，含 6 大类 28 子类 | train 约 269,359 题；val 280 题（含解析）；test 11,200 题 |
| CMB-Clin | 复杂临床问诊案例，以「病例描述 + 多轮问答」形式呈现 | 74 例 |
| CMB-Instruct（部分版本提供） | 指令微调数据 | 详见官方仓库发布版本 |

> 注：不同发布渠道（GitHub / HuggingFace）的子集划分可能略有差异，以官方最新发布为准。

## 5. 引用方式
```bibtex
@misc{cmedbenchmark,
  title     = {CMB: Chinese Medical Benchmark},
  author    = {Xidong Wang and Guiming Hardy Chen and Dingjie Song and Zhiyi Zhang and Qingying Xiao and Xiangbo Wu and Feng Jiang and Jianquan Li and Benyou Wang},
  year      = {2023},
  publisher = {GitHub},
  journal   = {GitHub repository},
  howpublished = {\url{https://github.com/FreedomIntelligence/CMB}}
}
```
- 论文 / arXiv：https://arxiv.org/abs/2308.08833

## 6. 在本项目中的说明
（请在此补充本项目如何使用 CMB 数据，例如数据存放路径、预处理 / 清洗方式、对应的训练或评测脚本等。）
