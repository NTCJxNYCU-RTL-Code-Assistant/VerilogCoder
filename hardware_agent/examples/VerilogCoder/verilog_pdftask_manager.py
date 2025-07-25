import os
import re
from hardware_agent.examples.VerilogCoder.verilog_examples_manager import VerilogCaseManager
from hardware_agent.examples.VerilogCoder.load_verilog_cases import list_files_in_directory
from hardware_agent.gptpdf import parse_pdf
import json
import shutil


class VerilogPDFTaskManager(VerilogCaseManager):

    def __init__(self,
                 file_path: str,
                 task_id: str = "task",
                 env_or_file: str = 'OAI_CONFIG_LIST'):
        assert os.path.isdir(file_path)

        self.file_path = file_path
        self.cur_task = 0
        self.verilog_cases = [{'task_id': task_id}]

        self.load_config(env_or_file)

        files: list[str] = list_files_in_directory(file_path)
        if len(files) == 0:
            print(
                "Error! There is no files in for loading verilog cases under ",
                file_path)
            exit(1)

        pdf_files = [file for file in files if file.endswith('.pdf')]
        if len(pdf_files) > 0:
            for pdf_file in pdf_files:
                self.convert_pdf_to_mdfile(os.path.join(file_path, pdf_file))

        for file in list_files_in_directory(file_path):
            # xxx.png or xxx.jpg: image
            if file.endswith('.png') or file.endswith('.jpg'):
                continue
            # xxx.pdf: spec pdf
            elif file.endswith('.pdf'):
                continue
            # xxx.md or xxx.txt: spec prompt
            elif file.endswith('.md') or file.endswith('.txt'):
                with open(os.path.join(file_path, file), 'r',
                          encoding='utf-8') as f:
                    content = f.read()
                content = self.convert_md_to_prompt(content)
                self.verilog_cases[0]['prompt'] = content
            # test or ref
            else:
                file_name_fields = file.split('.')
                problem_fields = file_name_fields[0].split('_')
                content_type = problem_fields[-1]

                print('reading ', file_path, file)
                with open(os.path.join(file_path, file), 'r') as f:
                    text = f.read()

                self.verilog_cases[0][content_type] = text

        # combine the ref to test for running iverilog
        for task in self.verilog_cases:
            if 'test' in task and 'ref' in task:
                task['test'] = task['test'] + "\n" + task['ref']

    def convert_pdf_to_mdfile(self, pdf_path: str):
        filename = os.path.basename(pdf_path).split('.')[0]
        output_dir = os.path.join(self.file_path, filename)
        os.makedirs(output_dir, exist_ok=True)
        config = self.config_list[0]
        parse_pdf(pdf_path,
                  output_dir=output_dir,
                  api_key=config['api_key'],
                  base_url=config['base_url'],
                  model=config['model'],
                  gpt_worker=6)

        for root, _, files_in_dir in os.walk(output_dir):
            for fname in files_in_dir:
                if fname.endswith('.log'):
                    continue
                src_path = os.path.join(root, fname)
                new_fname = f'{filename}_{fname}'
                dst_path = os.path.join(self.file_path, new_fname)

                if os.path.exists(dst_path):
                    os.remove(dst_path)
                os.rename(src_path, dst_path)

        shutil.rmtree(output_dir)

        md_file = os.path.join(self.file_path, f'{filename}_output.md')
        with open(md_file, 'r') as f:
            content = f.read()

        content = re.sub(r'!\[.*?\]\(([^)]+)\)',
                         lambda match: f'![]({filename}_{match.group(1)})',
                         content)

        with open(md_file, 'w') as f:
            f.write(content)

    def convert_md_to_prompt(self, md_content: str) -> str:
        return re.sub(
            r'!\[.*?\]\(([^)]+)\)', lambda match:
            f'<img "{os.path.join(self.file_path, match.group(1))}">',
            md_content)

    def load_config(self, env_or_file: str):
        env_str = os.environ.get(env_or_file)
        if env_str:
            # The environment variable exists. We should use information from it.
            if os.path.exists(env_str):
                # It is a file location, and we need to load the json from the file.
                with open(env_str, "r") as file:
                    json_str = file.read()
            else:
                # Else, it should be a JSON string by itself.
                json_str = env_str
            self.config_list = json.loads(json_str)
        else:
            # The environment variable does not exist.
            # So, `env_or_file` is a filename. We should use the file location.
            with open(env_or_file) as json_file:
                self.config_list = json.load(json_file)
