# VerilogCoder: Autonomous Verilog Coding Agents with Graph-based Planning and Abstract Syntax Tree (AST)-based Waveform Tracing Tool

## Description
VerilogCoder is an autonomous verilog coding agent that using graph-based planning and AST-based waveform tracing tool. The paper is in [https://arxiv.org/abs/2408.08927v1]. We use Verilog Eval Human v2 benchmarks on (https://github.com/NVlabs/verilog-eval/tree/main/dataset_spec-to-rtl) for experiments.

## LLM Models
The prompts are finetuned for GPT-4 and Llama3. User can switch to other LLM models with their own prompts.

## Benchmark and Generated .sv from VerilogCoder in the paper
- **Case Dir**: ```<project_home_dir>/hardware_agent/examples/VerilogCoder/verilog-eval-v2/```
- **Benchmark Dir**: ```<case_dir>/dataset_dumpall```
- **VerilogCoder Generated Plan Reference Dir**: ```<case_dir>/plans```
- **VerilogCoder Generated Verilog File Reference Dir**: ```<case_dir>/plan_output```

## Inputs and Outputs for VerilogCoder
- **Input**: Target RTL specification, and testbench. 
- **Output**: Completed functional correct Verilog module.

## Prerequisite Tool Installation
In order to run the waveform tracing tool, user need to install iverilog.

```
git clone https://github.com/steveicarus/iverilog.git && cd iverilog \ 
        && git checkout 01441687235135d1c12eeef920f75d97995da333 \ 
        && sh ./autoconf.sh  
./configure --prefix=<local dir> 
make –j4 
Make install 
export PATH=<local dir>:$PATH 
```

## Installation

1. Create conda environment
```
#Create conda env with python >= 3.10
conda create -n hardware_agent python=3.10.13
conda activate hardware_agent
```

2. Install the packages
```
#setup environment in conda env
pip install -e . or python setup.py install (non-editable mode)
pip install pypdf
pip install PILLOW
pip install network
pip install matplotlib
pip install pydantic==2.10.1
pip install langchain==0.3.14
pip install llangchain_openai==0.2.14
pip install langchain_community==0.3.14
pip install chromadb==0.4.24
pip install IPython 
pip install markdownify 
pip install pypdf 
pip install sentence_transformers==2.7.0
pip install -U chainlit 
export PYTHONPATH=<cur_dir_path>:$PYTHONPATH
```

## Quick Start
1. Use the OAI_CONFIG_LIST to setup the LLM models.
```
[
    {
        "model": "gpt-4-turbo",
	    "api_key": ""
    }
]
```

2. make a temp working directory.
```
mkdir verilog_tool_tmp
```

3. Select the cases to run VerilogCoder in hardware_agent/examples/VerilogCoder/run_verilog_coder.py using user_task_ids.
```
# Load verilog problem sets
# Add questions
user_task_ids = {'zero'}
case_manager = VerilogCaseManager(file_path=args.verilog_example_dir, task_ids=user_task_ids)
```

4. Run the command for "python hardware_agent/examples/VerilogCoder/run_verilog_coder.py --generate_plan_dir <TCRG_plan_dir> --generate_verilog_dir <Verilog_code_dir> --verilog_example_dir <Verilog_Eval_v2_benchmark_dir>".
   
Example:
```
python hardware_agent/examples/VerilogCoder/run_verilog_coder.py --generate_plan_dir <case_dir>/plans/ --generate_verilog_dir <case_dir>/plan_output/ --verilog_example_dir <case_dir>
```

## Signing Your Work
We require that all contributors "sign-off" on their commits. This certifies that the contribution is your original work, or you have rights to submit it under the same license, or a compatible license.

Any contribution which contains commits that are not Signed-Off will not be accepted.
To sign off on a commit you simply use the --signoff (or -s) option when committing your changes:
```
$ git commit -s -m "Add cool feature."
```
This will append the following to your commit message:
```
Signed-off-by: Your Name <your@email.com>
```
Full text of the DCO:

  Developer Certificate of Origin
  Version 1.1
  
  Copyright (C) 2004, 2006 The Linux Foundation and its contributors.
  1 Letterman Drive
  Suite D4700
  San Francisco, CA, 94129
  
  Everyone is permitted to copy and distribute verbatim copies of this license document, but changing it is not allowed.
  Developer's Certificate of Origin 1.1
  
  By making a contribution to this project, I certify that:
  
  (a) The contribution was created in whole or in part by me and I have the right to submit it under the open source license indicated in the file; or
  
  (b) The contribution is based upon previous work that, to the best of my knowledge, is covered under an appropriate open source license and I have the right under that license to submit that work with modifications, whether created in whole or in part by me, under the same open source license (unless I am permitted to submit under a different license), as indicated in the file; or
  
  (c) The contribution was provided directly to me by some other person who certified (a), (b) or (c) and I have not modified it.
  
  (d) I understand and agree that this project and the contribution are public and that a record of the contribution (including all personal information I submit with it, including my sign-off) is maintained indefinitely and may be redistributed consistent with this project or the open source license(s) involved.

## 直接建置在本機

1. clone VerilogCoder 專案

    ```bash
    $ git clone https://github.com/NVlabs/VerilogCoder.git
    ```

2. 前往 [iverilog 頁面](https://github.com/steveicarus/iverilog/releases) 下載 zip 或是 tar.gz
3. 在 clone 下來的 VerilogCoder 內解壓縮 iverilog，使資料夾結構如下

    ```yaml
    VerilogCoder
        |--iverilog
    ```

4. 確認本機的執行環境為 linux，或是使用 WSL
5. 在 VerilogCoder/iverilog 中執行以下指令

    ```bash
    $ sudo apt-get update
    $ sudo apt-get install -y autoconf gperf build-essential flex bison
    $ sh ./autoconf.sh
    $ ./configure
    $ make
    $ sudo make install
    ```

6. 若是 WSL 中沒有安裝 conda，執行以下指令安裝

    ```bash
    $ sudo apt-get install wget
    $ wget https://repo.anaconda.com/archive/Anaconda3-2024.02-1-Linux-x86_64.sh
    $ bash Anaconda3-2024.02-1-Linux-x86_64.sh
    # 一直按 enter
    # yes
    # 按 enter 以安裝預設位置
    # yes
    $ source ~/.bashrc
    ```

7. 回到 VerilogCoder，建立 conda 環境，並安裝環境

    ```bash
    $ conda create -n hardware_agent python=3.10.13
    $ pip install -e .
    $ pip install -r requirements.txt
    ```

8. 建置完成

## 建置在 docker / podman container 中

1. clone VerilogCoder 專案

    ```bash
    $ git clone https://github.com/NVlabs/VerilogCoder.git
    ```

2. 在 VerilogCoder 中新增 Dockerfile 如下

    ```docker
    FROM continuumio/miniconda3

    # Set up the working directory
    WORKDIR /app

    # Copy the current directory contents into the container at /app
    COPY . /app

    # Install necessary build tools and pip
    RUN apt-get update && \
        apt-get install -y git autoconf gperf build-essential flex bison && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*

    # Install prerequisite tools
    RUN git clone https://github.com/steveicarus/iverilog.git && cd iverilog \
        && sh ./autoconf.sh && ./configure --prefix=/usr/local && make -j4 && make install

    # Set environment variables
    ENV PATH=/opt/conda/bin:$PATH

    # Create conda environment
    RUN conda create -n hardware_agent python=3.10.13 && \
        echo "source activate hardware_agent" > ~/.bashrc && \
        /bin/bash -c "source ~/.bashrc && conda activate hardware_agent && \
        pip install -e . && \
        pip install -r requirements.txt"

    # Set environment variables
    ENV PYTHONPATH=/app
    ```

3. 以 docker 舉例，以 Dockerfile 建置 image 後執行

    ```bash
    # 建置 image，名字為 verilogcoder，避免 Dockerfile 被 cache 住
    $ docker build -t verilogcoder . --no-cache
    # 執行 container，執行結束後直接清除該 container
    # 掛載外部的 artifacts 資料夾到內部的 /app/artifacts 資料夾
    $ docker run -it --rm -v ./aritfacts/:/app/artifacts/ verilogcoder bash
    ```

4. 建置完成，可以在 container 中執行了

## 執行 VerilogCoder

在 VerilogCoder 資料夾中，執行以下指令

```bash
$ python ./hardware_agent/examples/VerilogCoder/run_verilog_coder.py \
	--generate_plan_dir ./artifacts_test/plans/ \ # 指定生成 plan 的資料夾路徑
	--generate_verilog_dir ./artifacts_test/generate_verilog/ \ # 指定生成完成的 verilog 資料夾路徑
	--verilog_tmp_dir ./artifacts_test/verilog_tmp_dir/ \ # 指定 agent 生成暫存檔的資料夾路徑
	--verilog_example_dir ./hardware_agent/examples/VerilogCoder/verilog-eval-v2/dataset_dumpall/ \ # 指定測資所在的資料夾
	--oai_config OAI_CONFIG_LIST \ #設定要使用哪一個 LLM 的 config
	--max_tokens 10240 #設定 LLM 的 max_tokens
	> ./artifacts_test/log # 將輸出導至 log 檔
```

使用模型設定

```json
// VerilogCoder/OAI_CONFIG_LIST
[
	{
		"model": "gpt-4o", // 模型名稱
		"base_url": "https://api.openai.com/v1", // 模型 api url
		"api_key": "sk-xxxxxxxxxxxxxxxxxxxxx", // 就算因為是 sk-proj 導致跳出警告，還是能執行的
	}
]
```

設定要測試的問題集

```python
# VerilogCoder/hardware_agent/examples/VerilogCoder/run_verilog_coder.py, line 41
user_task_ids = {'zero'} # 可在這邊設定要使用的 testcase

# 可以在 VerilogCoder/hardware_agent/examples/VerilogCoder/verilog-eval-v2/dataset_dumpall/problems.txt
# 查看 testcase 有哪些
```

## 🚀 擴充功能說明（Extended Features / Custom Modifications）

本專案在原始 VerilogCoder 架構之上，額外實作了以下兩項擴充功能，以提升系統的彈性與可擴展性。

---

### 🔹 功能一：多 Agent 使用不同 LLM 模型（Multi-LLM per Agent）

本功能支援為系統中的**不同 Agent 指派不同的 LLM 模型與 API 設定**，不再限制所有 Agent 共用同一組 LLM。

透過此機制，可以：

* 讓不同角色的 Agent 使用最適合的模型（例如除錯 Agent 使用推理能力較強的模型）
* 同時測試多種模型組合對整體系統效能的影響
* 提升多 Agent 協作時的彈性與實驗自由度

---

#### 🧩 支援的 Agent 角色

目前系統支援以下 Agent，皆可獨立指定所使用的 LLM：

* `task_planner`：負責解析任務需求與規劃整體實作流程
* `kg`：負責知識圖譜（Knowledge Graph）相關推理與輔助決策
* `graph_retrieval`：負責圖結構與相關資訊檢索
* `verilog_writing`：負責主要 Verilog RTL 程式碼生成
* `verilog_debug`：負責錯誤分析、除錯與功能修正
* `submodule_spec`：負責子模組規格分析與模組拆解設計

---

#### ⚙️ 設定方式（Multi-LLM Configuration）

使用者可在設定檔中指定特定 Agent 使用專屬的 LLM，其餘 Agent 使用預設模型（`other`）。

範例如下：

```json
// VerilogCoder/OAI_CONFIG_LIST
{
    "verilog_debug": {
        "model": "o3",
        "base_url": "https://api.openai.com/v1",
        "api_key": "YOUR_OPENAI_API_KEY"
    },
    "other": {
        "model": "openai/gpt-4o",
        "base_url": "https://openrouter.ai/api/v1",
        "api_key": "YOUR_OPENROUTER_API_KEY"
    }
}
```

說明：

* `verilog_debug`：指定除錯 Agent 使用特定模型（此例為 OpenAI o3）
* `other`：作為其餘所有 Agent 的預設模型設定
* 每個 Agent 皆可獨立指定：

  * `model`：模型名稱
  * `base_url`：API 端點
  * `api_key`：對應平台的 API 金鑰

---


### 🔹 功能二：Submodule 分開實作（Submodule-Level Verilog Generation）

本功能支援 VerilogCoder 將設計拆分為多個子模組（submodules）分別生成，並將生成後的子模組**自動替換原本設計中的對應 submodule**，再透過既有的 top module 與 testbench 進行功能驗證。

此模式適合較大型或結構較複雜的 RTL 任務，可提升生成結果的模組化程度、可讀性與除錯效率，同時保留原始 top-level 設計架構不變。

---

#### ✅ 使用前需準備的 3 種檔案

啟用 submodule 分開實作模式時，使用者需額外提供以下三種檔案：

1. **Refmodule（參考模組 / 介面定義）**

   * 用途：提供原始 top module 的介面定義與模組架構作為生成與驗證依據
   * 內容通常包含：module 名稱、port 宣告，以及既有 submodule 的 instance 介面

2. **Submodule List（子模組清單）**

   * 用途：指定需要重新生成並替換的 submodule 名稱清單
   * 系統將依此清單逐一生成對應的子模組實作

3. **Testbench（測試平台）**

   * 用途：用於驗證「原始 top module + 替換後 submodules」組合後的功能正確性

---

#### 📂 檔案放置方式（範例）

三種檔案需放置於同一個測資資料夾中，例如：

```text
prob001_bubble_sort_ref.sv
prob001_bubble_sort_submodule.txt
prob001_bubble_sort_test.sv
```

---

#### ▶️ 使用方式（啟用 Submodule Mode）

執行 VerilogCoder 時加入參數 `--submodule_mode True` 即可啟用 submodule 分開實作模式，例如：

```bash
python ./hardware_agent/examples/VerilogCoder/run_verilog_coder.py \
    --generate_plan_dir ./artifacts_test/plans/ \
    --generate_verilog_dir ./artifacts_test/generate_verilog/ \
    --verilog_tmp_dir ./artifacts_test/verilog_tmp_dir/ \
    --verilog_example_dir ./hardware_agent/examples/VerilogCoder/opencores/dataset_dumpall/ \
    --oai_config OAI_CONFIG_LIST \
    --submodule_mode True \
    > ./artifacts_test/log
```

執行流程說明：

1. 系統依據 `submodule_list` 逐一生成各子模組的 Verilog 實作
2. 生成完成後，**自動以新生成的 submodule 檔案替換原始設計中的對應 submodule**
3. 保留原本的 top module 架構不變
4. 使用提供的 testbench 進行自動編譯與模擬驗證，以確認替換後系統功能是否正確


