#
# SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
# Author : Chia-Tung (Mark) Ho, NVIDIA
#

from hardware_agent.examples.VerilogCoder.verilogcoder import VerilogCoder
from autogen import config_list_from_json
from hardware_agent.examples.VerilogCoder.verilog_examples_manager import VerilogCaseManager
from hardware_agent.examples.VerilogCoder.load_verilog_cases import load_verilog_eval2_cases
from hardware_agent.examples.VerilogCoder.auto_gen_submodule import gen_submodule_spec
import argparse
import os
import weave
import copy
import shutil
from pathlib import Path
"""
example command: python hardware_agent/examples/VerilogCoder/run_verilog_coder.py --generate_plan_dir 
hardware_agent/examples/VerilogCoder/verilog-eval-v2/plans/ --generate_verilog_dir hardware_agent/examples/VerilogCoder/verilog-eval-v2/plan_output/ 
--verilog_example_dir hardware_agent/examples/VerilogCoder/verilog-eval-v2/dataset_dumpall/
"""

parser = argparse.ArgumentParser(
    description=
    'VerilogCoder: Autonomous Autonomous Verilog Coding Agents with Graph-based '
    'Planning and Abstract Syntax Tree (AST)-based Waveform Tracing Tool',
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('--generate_plan_dir',
                    help="Plan directory for generated plans",
                    default="./generated_verilog_plans/")
parser.add_argument(
    '--generate_verilog_dir',
    help="Verilog directory for generated functional correct Verilog module",
    default="./generate_verilog_dir/")
parser.add_argument('--verilog_tmp_dir',
                    help="Temp directory for agent",
                    default="./verilog_tool_tmp/")
parser.add_argument('--verilog_example_dir',
                    help="Verilog question set dir",
                    default="./verilog_eval_v2/")
parser.add_argument('--oai_config',
                    help="OAI_CONFIG_LIST",
                    default="OAI_CONFIG_LIST")
parser.add_argument('--max_tokens',
                    help="LLM_max_tokens",
                    default=10240)
parser.add_argument('--weave',
                    help="your weave config list")
parser.add_argument('--submodule_mode',
                    help="whether use submodule_mode",
                    type=bool,
                    default=False)
args = parser.parse_args()
print(args)

# create the tmp directory for plan graph
tmp_dir = "./tmp/"
if not os.path.exists(tmp_dir):
    os.makedirs(tmp_dir)
    print(f"Created directory: {tmp_dir}")
else:
    print(f"Directory already exists: {tmp_dir}")

# llm configurations
gpt4_config_list = config_list_from_json(env_or_file=args.oai_config)

gpt_reasoning_model = ["o3","o4-mini","gpt-5-mini","gpt-5"]
if isinstance(gpt4_config_list, list):    
    if gpt4_config_list[0]["model"] not in gpt_reasoning_model:
        gpt4_config_list[0]["max_tokens"] = args.max_tokens
    else:
        gpt4_config_list[0]["max_completion_tokens"] = args.max_tokens
        gpt4_config_list[0]["temperature"] = 1
    task_planner_llm_gpt4_config_list = copy.deepcopy(gpt4_config_list)
    kg_llm_gpt4_config_list = copy.deepcopy(gpt4_config_list)
    graph_retrieval_llm_gpt4_config_list = copy.deepcopy(gpt4_config_list)
    verilog_writing_llm_gpt4_config_list = copy.deepcopy(gpt4_config_list)
    verilog_debug_llm_gpt4_config_list = copy.deepcopy(gpt4_config_list)
    submodule_spec_gpt4_config_list = copy.deepcopy(gpt4_config_list)

elif isinstance(gpt4_config_list, dict):
    for name in gpt4_config_list.keys():
        if gpt4_config_list[name]["model"] not in gpt_reasoning_model:
            gpt4_config_list[name]["max_tokens"] = args.max_tokens
        else:
            gpt4_config_list[name]["max_completion_tokens"] = args.max_tokens
            gpt4_config_list[name]["temperature"] = 1
    task_planner_llm_gpt4_config_list = [copy.deepcopy(gpt4_config_list["other"])]
    kg_llm_gpt4_config_list = [copy.deepcopy(gpt4_config_list["other"])]
    graph_retrieval_llm_gpt4_config_list = [copy.deepcopy(gpt4_config_list["other"])]
    verilog_writing_llm_gpt4_config_list = [copy.deepcopy(gpt4_config_list["other"])]
    verilog_debug_llm_gpt4_config_list = [copy.deepcopy(gpt4_config_list["other"])]
    submodule_spec_gpt4_config_list = [copy.deepcopy(gpt4_config_list["other"])]
    for name in gpt4_config_list.keys():
        if name == "task_planner":
            task_planner_llm_gpt4_config_list = [copy.deepcopy(gpt4_config_list["task_planner"])]
        elif name == "kg":
            kg_llm_gpt4_config_list = [copy.deepcopy(gpt4_config_list["kg"])]
        elif name == "graph_retrieval":
            graph_retrieval_llm_gpt4_config_list = [copy.deepcopy(gpt4_config_list["graph_retrieval"])]
        elif name == "verilog_writing":
            verilog_writing_llm_gpt4_config_list = [copy.deepcopy(gpt4_config_list["verilog_writing"])]
        elif name == "verilog_debug":
            verilog_debug_llm_gpt4_config_list = [copy.deepcopy(gpt4_config_list["verilog_debug"])]
        elif name == "submodule_spec":
            submodule_spec_gpt4_config_list = [copy.deepcopy(gpt4_config_list["submodule_spec"])]

    
task_planner_llm_gpt4_config_list[0]["max_completion_tokens"] = 10240
kg_llm_gpt4_config_list[0]["max_completion_tokens"] = 10240
graph_retrieval_llm_gpt4_config_list[0]["max_completion_tokens"] = 10242
verilog_writing_llm_gpt4_config_list[0]["max_completion_tokens"] = 10243
verilog_debug_llm_gpt4_config_list[0]["max_completion_tokens"] = 10244
# llama3 settings: Used for comparison
llm_configs = {
    "task_planner_llm": task_planner_llm_gpt4_config_list,
    "kg_llm": kg_llm_gpt4_config_list,
    "graph_retrieval_llm": graph_retrieval_llm_gpt4_config_list,
    "verilog_writing_llm": verilog_writing_llm_gpt4_config_list,
    "verilog_debug_llm": verilog_debug_llm_gpt4_config_list
}

#weave
if args.weave != None:
    weave_config_list = config_list_from_json(env_or_file=args.weave)
    client = weave.init(weave_config_list[0]["name"])

print("[Info]: VerilogCoder llm configs = ", llm_configs)

# Load verilog problem sets
# Add questions
user_task_ids = {'sha3'}
# user_task_ids = {'bubble_sort'}
#user_task_ids = {'rs_decoder'}
# user_task_ids = {'ece241_2014_q4'}
# user_task_ids = {'zero'}
# user_task_ids = {"sha3_high_thoughput"}

# with open(args.verilog_example_dir + "/problems.txt", "r") as f:
#     user_task_ids = set(
#         ['_'.join(line.strip().split('_')[1:]) for line in f.readlines()])

# with open(args.verilog_example_dir + "/problems_part.txt", "r") as f:
#     user_task_ids = set(
#         ['_'.join(line.strip().split('_')[1:]) for line in f.readlines()])

if args.submodule_mode == True:
    task_cases = load_verilog_eval2_cases(args.verilog_example_dir, user_task_ids)

    user_task_ids = set()
    folder = Path(os.path.join(args.verilog_example_dir, "tmp"))
    if folder.exists() and folder.is_dir():
        shutil.rmtree(folder)

    for task_case in task_cases:
        user_task_ids.update(gen_submodule_spec(task_case, args.verilog_example_dir, submodule_spec_gpt4_config_list))
    args.verilog_example_dir = os.path.join(args.verilog_example_dir, "tmp")

# exit()
        
case_manager = VerilogCaseManager(file_path=args.verilog_example_dir,
                                  task_ids=user_task_ids)

llm_types = {}
for key in llm_configs.keys():
    if "llama3" in llm_configs[key][0]["model"]:
        llm_types[key] = "llama3"
    else:
        llm_types[key] = "gpt"
print("[Info]: VerilogCoder llm types = ", llm_types)

coding_agent = VerilogCoder(
    task_planner_llm_config=llm_configs["task_planner_llm"],
    kg_llm_config=llm_configs["kg_llm"],
    graph_retrieval_llm_config=llm_configs["graph_retrieval_llm"],
    verilog_writing_llm_config=llm_configs["verilog_writing_llm"],
    debug_llm_config=llm_configs["verilog_debug_llm"],
    llm_types=llm_types,
    generate_plan_dir=args.generate_plan_dir,
    generate_verilog_dir=args.generate_verilog_dir,
    verilog_tmp_dir=args.verilog_tmp_dir)

pass_tasks = []
failed_tasks = []
for _ in range(case_manager.total_tasks()):
    cur_task_id = case_manager.get_cur_task_id()
    # if os.path.exists(args.generate_plan_dir + "/" + cur_task_id + "_plan.json"):
    #    plan_filename = args.generate_plan_dir + "/" + cur_task_id + "_plan.json"
    #    have_plans = True
    # else:
    plan_filename = ""
    have_plans = False
    success = coding_agent.write_Verilog_module(
        cur_task_id=cur_task_id,
        spec=case_manager.get_cur_prompt(),
        top_module=case_manager.get_cur_top_module(),
        golden_test_bench=case_manager.get_cur_task_test(),
        plan_filename=plan_filename,
        have_plans=have_plans)
    if success:
        pass_tasks.append(cur_task_id)
    else:
        failed_tasks.append(cur_task_id)
    # Next verilog case
    case_manager.next()

print('passed tasks: ', len(pass_tasks), '\n', pass_tasks, '\n')
print('failed tasks: ', len(failed_tasks), '\n', failed_tasks, '\n')
print('success rate: ', len(pass_tasks) / case_manager.total_tasks())

print(args.verilog_example_dir)
# if args.submodule_mode == True:
#     folder = Path(args.verilog_example_dir)
#     if folder.exists() and folder.is_dir():
#         shutil.rmtree(folder)