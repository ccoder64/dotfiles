"""在临时 HOME 中运行完整安装器, 用模拟包管理器和下载源隔离系统副作用."""

import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MOCK = r'''
import json, os, pathlib, shutil, sys
name, args = pathlib.Path(sys.argv[0]).name, sys.argv[1:]
root = pathlib.Path(os.environ["FIXTURE"])
with (root / "calls.jsonl").open("a") as log:
    log.write(json.dumps({"cmd": name, "args": args}) + "\n")
if name == "uname":
    print(os.environ.get("MOCK_OS", "Linux") if args == ["-s"] else os.environ.get("MOCK_ARCH", "x86_64"))
elif name == "id":
    print(os.environ.get("MOCK_UID", "0"))
elif name == "sudo":
    os.execvp(args[0], args)
elif name in ("apt-get", "dnf"):
    if "install" in args:
        for cmd in ("curl", "rsync", "git", "vim", "zoxide"):
            target = root / "bin" / cmd
            if cmd in args and not target.exists():
                target.symlink_to(root / "mock")
        target = root / "bin/jq"
        if "jq" in args and not target.exists():
            target.symlink_to(os.environ["REAL_JQ"])
        target = root / "bin/gzip"
        if "gzip" in args and not target.exists():
            target.symlink_to(os.environ["REAL_GZIP"])
elif name == "brew":
    if args[0] == "bundle":
        (root / "Brewfile").write_text(sys.stdin.read())
    elif args == ["install", "herdr"]:
        target = root / "bin/herdr"
        target.symlink_to(root / "mock")
elif name == "curl":
    url = next(arg for arg in args if arg.startswith("http"))
    output = pathlib.Path(args[args.index("-o") + 1]) if "-o" in args else None
    if url.endswith("/country"):
        print("US")
    elif "/releases/latest" in url:
        repo = url.split("/repos/")[1].split("/releases/latest")[0]
        assets = json.loads((root / "releases.json").read_text())[repo]
        print(json.dumps({"assets": assets}))
    elif "plug.vim" in url:
        output.write_text('" fixture plug.vim\n')
    else:
        filename = url.rsplit("/", 1)[1]
        if os.environ.get("FAIL_ASSET") == filename:
            output.write_text("incomplete download")
            sys.exit(22)
        shutil.copyfile(root / "assets" / filename, output)
elif name in ("rsync", "git"):
    os.execv(os.environ["REAL_" + name.upper()], [name] + args)
elif name == "tar":
    # BSD tar 默认支持提取通配符, 不接受 GNU tar 的 --wildcards 开关.
    if sys.platform == "darwin":
        args = [arg for arg in args if arg != "--wildcards"]
    os.execv(os.environ["REAL_TAR"], [name] + args)
elif name == "vim":
    if os.environ.get("FAIL_VIM"):
        print("fixture Vim failure", file=sys.stderr)
    sys.exit(int(os.environ.get("FAIL_VIM", "0")))
elif name == "fzf":
    if "--bash" not in args:
        rows = sys.stdin.read().splitlines()
        if not rows or os.environ.get("CANCEL_FZF"):
            sys.exit(130)
        print(rows[0])
elif name in ("starship", "zoxide"):
    if args == ["--version"]:
        print(name + " fixture")
else:
    print(name + " fixture")
'''


class DotfilesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.repo = self.root / "repo"
        shutil.copytree(ROOT, self.repo, ignore=shutil.ignore_patterns(".git", "__pycache__"))
        self.mock = self.root / "mock"
        self.mock.write_text(f"#!{sys.executable}\n" + MOCK)
        self.mock.chmod(0o755)
        self.env = {
            "HOME": str(self.home), "PATH": str(self.bin), "FIXTURE": str(self.root),
            "TERM": "xterm-256color", "LC_ALL": "C", "GIT_CONFIG_NOSYSTEM": "1",
        }
        for name in ("cat", "chmod", "cp", "dirname", "env", "grep", "ln",
                     "mkdir", "mktemp", "mv", "rm", "sed", "touch"):
            (self.bin / name).symlink_to(shutil.which(name))
        for name in ("jq", "git", "rsync", "gzip", "tar"):
            self.env["REAL_" + name.upper()] = shutil.which(name)
        for name in ("uname", "id", "apt-get", "tar"):
            self.stub(name)
        self.make_releases()

    def stub(self, name, directory=None):
        path = (directory or self.bin) / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.symlink_to(self.mock)

    def calls(self):
        path = self.root / "calls.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def make_releases(self, arch="x86_64"):
        assets_dir = self.root / "assets"
        assets_dir.mkdir(exist_ok=True)
        rust = "aarch64" if arch == "aarch64" else "x86_64"
        short = "arm64" if arch == "aarch64" else "amd64"
        releases = {}

        def asset(repo, filename, members):
            releases.setdefault(repo, []).append({
                "name": filename, "browser_download_url": "https://downloads.invalid/" + filename,
            })
            target = assets_dir / filename
            if members is None:
                target.write_text("#!/bin/sh\nexit 0\n")
                return
            with tarfile.open(target, "w:gz") as archive:
                for member in members:
                    content = b"#!/bin/sh\nexit 0\n"
                    info = tarfile.TarInfo(member)
                    info.mode, info.size = 0o755, len(content)
                    archive.addfile(info, io.BytesIO(content))

        asset("str4d/rage", f"rage-v1.0-{short if arch == 'aarch64' else rust}-linux.tar.gz", ["rage/rage", "rage/rage-keygen"])
        for libc in ("gnu", "musl"):
            asset("dandavison/delta", f"delta-{rust}-unknown-linux-{libc}.tar.gz", ["delta/delta"])
            asset("eza-community/eza", f"eza_{rust}-unknown-linux-{libc}.tar.gz", ["./eza"])
        asset("ajeetdsouza/zoxide", f"zoxide-{rust}-unknown-linux-musl.tar.gz", ["zoxide"])
        asset("sharkdp/bat", f"bat-{rust}-unknown-linux-musl.tar.gz", ["bat/bat"])
        asset("junegunn/fzf", f"fzf-linux_{short}.tar.gz", ["fzf"])
        fastfetch = "aarch64" if arch == "aarch64" else "amd64"
        asset("fastfetch-cli/fastfetch", f"fastfetch-linux-{fastfetch}.tar.gz", [f"fastfetch-linux-{fastfetch}/usr/bin/fastfetch"])
        asset("starship/starship", f"starship-{rust}-unknown-linux-musl.tar.gz", ["starship"])
        asset("herdrdev/herdr", f"herdr-linux-{rust}", None)
        asset("charmbracelet/glow", f"glow_1.0_Linux_{'arm64' if arch == 'aarch64' else rust}.tar.gz", ["glow_1.0/glow"])
        asset("mikefarah/yq", f"yq_linux_{short}", None)
        asset("bootandy/dust", f"dust-{rust}-unknown-linux-musl.tar.gz", ["dust/dust"])
        (self.root / "releases.json").write_text(json.dumps(releases))

    def install(self, expected=0):
        result = subprocess.run(
            ["/bin/bash", str(self.repo / "install.sh")],
            env=self.env, text=True, capture_output=True, timeout=30,
        )
        if expected == 0:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertNotIn("🎉 安装完成", result.stdout)
        self.assertEqual(list((self.home / ".local/bin").glob(".dotfiles.*")), [])
        return result

    def test_bootstrap_root_and_repeat(self):
        self.assertFalse((self.bin / "curl").exists())
        self.assertFalse((self.bin / "rsync").exists())
        for rc in (".bashrc", ".zshrc"):
            (self.home / rc).write_text("# existing customization\n")
        self.install()
        calls = self.calls()
        install = next(i for i, c in enumerate(calls) if c["cmd"] == "apt-get" and "install" in c["args"])
        country = next(i for i, c in enumerate(calls) if c["cmd"] == "curl")
        self.assertLess(install, country)
        self.assertFalse(any(c["cmd"] == "sudo" for c in calls))
        vim_args = next(c["args"] for c in calls if c["cmd"] == "vim")
        self.assertEqual(vim_args[vim_args.index("-u") + 1], str(self.home / ".vimrc"))
        for cmd in ("rage", "rage-keygen", "delta", "eza", "bat", "fzf",
                    "fastfetch", "starship", "herdr", "glow", "yq", "dust"):
            self.assertTrue(os.access(self.home / ".local/bin" / cmd, os.X_OK), cmd)
        before = len([c for c in calls if c["cmd"] == "curl" and "/releases/latest" in " ".join(c["args"])])
        source = self.repo / "home/.gitconfig"
        replacement = source.with_suffix(".new")
        replacement.write_text(source.read_text() + "\n# updated source\n")
        replacement.replace(source)
        self.install()
        after = len([c for c in self.calls() if c["cmd"] == "curl" and "/releases/latest" in " ".join(c["args"])])
        self.assertEqual(before, after)
        self.assertIn("# updated source", (self.home / ".gitconfig").read_text())
        self.assertEqual((self.home / ".bashrc").read_text().count("source '"), 1)
        for rc in (".bashrc", ".zshrc"):
            content = (self.home / rc).read_text()
            self.assertEqual(content.count('. "$HOME/.config/shell/env.sh"'), 1)
            self.assertIn("# existing customization", content)
        self.assertEqual(
            (self.home / ".codex/shell-env.sh").read_text(),
            (self.repo / "home/.codex/shell-env.sh").read_text(),
        )
        self.assertFalse((self.home / ".tmux.conf").exists())

    def test_private_environment_and_codex_overrides(self):
        private = self.home / ".config/shell/env.sh"
        private.parent.mkdir(parents=True)
        private.write_text("export PRIVATE_FIXTURE='configured'\n")
        # 不需要安装软件即可验证实际安装器生成的加载语句.
        loader = re.search(r"^ENV_LOADER='([^']+)'$", (ROOT / "install.sh").read_text(), re.M).group(1)
        script = loader + '\nprintf "%s\\n" "$PRIVATE_FIXTURE" "$BASH_ENV"'
        for shell in ("/bin/bash", shutil.which("zsh")):
            if shell is None:
                continue
            with self.subTest(shell=shell):
                result = subprocess.run(
                    [shell, "-c", script],
                    env={**self.env, "PRIVATE_FIXTURE": "stale", "BASH_ENV": "/dev/null"},
                    text=True, capture_output=True, check=True,
                )
                self.assertEqual(result.stdout.splitlines(), ["configured", "/dev/null"])
        for value in ("temporary", ""):
            with self.subTest(override=value):
                result = subprocess.run(
                    ["/bin/bash", "-c", 'PRIVATE_FIXTURE="$1" /bin/bash -c \'printf "%s\\n" "$PRIVATE_FIXTURE" "$BASH_ENV"\'', "test", value],
                    env={**self.env, "BASH_ENV": str(ROOT / "home/.codex/shell-env.sh")},
                    text=True, capture_output=True, check=True,
                )
                self.assertEqual(result.stdout.splitlines(), [value, ""])
        private.unlink()
        result = subprocess.run(
            ["/bin/bash", "-c", loader], env=self.env, text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_dnf_arm64_sudo_and_explicit_proxy(self):
        (self.bin / "apt-get").unlink()
        self.stub("dnf")
        self.stub("sudo")
        self.env.update(MOCK_UID="1000", MOCK_ARCH="aarch64", PREFIX_PROXY="https://proxy.invalid/")
        self.make_releases("aarch64")
        self.install()
        calls = self.calls()
        self.assertTrue(any(c["cmd"] == "sudo" for c in calls))
        urls = [a for c in calls if c["cmd"] == "curl" for a in c["args"] if a.startswith("http")]
        self.assertTrue(all(url.startswith("https://proxy.invalid/https://") for url in urls))
        self.assertTrue(any("delta-aarch64-unknown-linux-musl" in url for url in urls))
        self.assertTrue(any("herdr-linux-aarch64" in url for url in urls))

    def test_nonroot_without_sudo_fails_clearly(self):
        self.env["MOCK_UID"] = "1000"
        result = self.install(expected=1)
        self.assertIn("root 权限或 sudo", result.stderr)

    def test_download_failure_and_broken_binary_recover(self):
        self.env["FAIL_ASSET"] = "herdr-linux-x86_64"
        self.install(expected=1)
        self.assertFalse((self.home / ".local/bin/herdr").exists())
        self.assertTrue((self.home / ".local/bin/rage").exists())
        del self.env["FAIL_ASSET"]
        self.install()
        glow = self.home / ".local/bin/glow"
        glow.write_text("#!/bin/sh\nexit 1\n")
        fzf = self.home / ".local/bin/fzf"
        fzf.write_text('#!/bin/sh\n[ "$1" != "--bash" ]\n')
        self.install()
        self.assertEqual(subprocess.run([str(glow), "--version"]).returncode, 0)
        self.assertEqual(subprocess.run([str(fzf), "--bash"]).returncode, 0)

    def test_vim_failure_is_not_success(self):
        self.env["FAIL_VIM"] = "2"
        result = self.install(expected=1)
        self.assertIn("Vim 插件同步失败", result.stderr)
        self.assertIn("fixture Vim failure", result.stderr)

    def test_macos_reuses_herdr_and_installs_selected_tools(self):
        self.env["MOCK_OS"] = "Darwin"
        for name in ("brew", "curl", "rsync", "git", "vim"):
            self.stub(name)
        local = self.home / ".local/bin"
        self.stub("herdr", local)
        self.install()
        brewfile = (self.root / "Brewfile").read_text()
        for name in ("glow", "yq", "dust", "starship", "jq", "htop"):
            self.assertIn(f'brew "{name}"', brewfile)
        self.assertNotIn('brew "tmux"', brewfile)
        self.assertFalse(any(c["cmd"] == "brew" and c["args"] == ["install", "herdr"] for c in self.calls()))

    def test_rgi_opens_matching_line_and_cancellation_does_not_edit(self):
        (self.bin / "rg").symlink_to(shutil.which("rg"))
        self.stub("fzf")
        self.stub("vim")
        target = self.root / "source file:quoted'name.txt"
        target.write_text("first\nneedle here\n")
        script = 'source "$1"; rgi needle "$2"'
        args = ["/bin/bash", "-c", script, "test", str(ROOT / "lib/functions.sh"), str(target)]
        result = subprocess.run(args, env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        edits = [c for c in self.calls() if c["cmd"] == "vim"]
        self.assertEqual(edits[0]["args"], ["+2", "--", str(target)])
        self.env["CANCEL_FZF"] = "1"
        result = subprocess.run(args, env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len([c for c in self.calls() if c["cmd"] == "vim"]), 1)

    def test_shell_reload_preserves_fzf_customization(self):
        for name in ("fzf", "starship", "zoxide", "bat"):
            self.stub(name)
        self.env.update(FZF_CTRL_T_COMMAND="", FZF_CTRL_T_OPTS="--height=40%", HISTFILE="/dev/null")
        (self.bin / "rg").symlink_to(shutil.which("rg"))
        script = 'source "$1"; source "$1"; printf "%s\\n" "$PROMPT_COMMAND" "$FZF_CTRL_T_COMMAND" "$FZF_CTRL_T_OPTS"'
        result = subprocess.run(
            ["/bin/bash", "--noprofile", "--norc", "-ic", script, "test", str(ROOT / "home/.bashrc")],
            env=self.env, text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["history -a", "", "--height=40%"])

    def test_codespaces_patch_does_not_stack_comments(self):
        script = (ROOT / "install.sh").read_text()
        expression = re.search(r"as_root sed -i '([^']+)'", script).group(1)
        original = "# existing comment\ndeb https://example.invalid stable main\n"
        first = subprocess.run(["sed", expression], input=original, text=True, capture_output=True, check=True).stdout
        second = subprocess.run(["sed", expression], input=first, text=True, capture_output=True, check=True).stdout
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()
