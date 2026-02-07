#!/usr/bin/env python3
#################
#
#
import fnmatch
import hashlib
import json
import os
import pathlib
import sys
from typing import NoReturn

########################################
#
#

# Style options:
# - Tree: Shows the directory structure with tree-like prefixes. (Default)
# - Flat: Shows the full path of each file without tree prefixes.
#
# Recursive review of contents is done by default, but can be limited to a certain depth if desired (not implemented yet).
#
# Expand Links: By default, symbolic links are not followed and are hashed based on their link target.
#               An option to follow links and hash the contents they point to could be added in the future.
#               (But we would need to be careful to avoid infinite loops with circular links.)
#
VERSION = "V0.0.1"
GIT_REPO_ORIG = "https://github.com/Mac-H/dir-hash"


def get_exe_name() -> str:
    tilde_home = os.getenv("HOME", "~") + "/"
    cwd = os.getcwd().removesuffix("/") + "/"
    nameIn = sys.argv[0] if len(sys.argv) > 0 else os.path.abspath(__file__)
    if "/" in nameIn:
        nameUse = os.path.abspath(nameIn)
    else:
        nameUse = nameIn
    dir = os.path.dirname(nameUse).removesuffix("/")
    paths = f"{os.getenv('PATH')}".split(":")
    if dir in paths or f"{dir}/" in paths:
        nameUse = os.path.basename(nameUse)
    elif nameUse.startswith(cwd):
        nameUse = nameUse.removeprefix(cwd)
    elif nameUse.startswith(tilde_home):
        nameUse = "~/" + nameUse.removeprefix(tilde_home)

    return nameUse


def main():

    styling = PathReviewStyling()

    ############
    exeName = get_exe_name()

    sys.argv.pop(0)

    nonParamArgs = []
    if True:
        _doExitWith = None
        _processParams = True
        _giveHelp = False
        for x in sys.argv:
            if not _processParams or not x.startswith("-"):
                nonParamArgs.append(x)
            elif x == "--":
                _processParams = False
            elif x == "--help" or x == "-h":
                _giveHelp = True
                _doExitWith = 0
            elif x == "--version":
                print(f"{exeName}   ({VERSION})")
                _doExitWith = 0
            elif x.startswith("-"):
                Utils.log_warning(f"Unknown command line argument: {x}")
                _doExitWith = 1

        if (_doExitWith is None) and len(nonParamArgs) > 1:
            Utils.log_error(
                f"Expected only a single directory to process, but found {len(nonParamArgs)}.",
                isFatal=False,
            )
            _giveHelp = True
            _doExitWith = 1

        if _giveHelp:
            print(
                f"Generates a hash summary of the directory contents for text diff comparison           ({VERSION})"
            )
            print(
                f"Usage: {exeName} [dir]    (If no dir is given, the current directory is used)"
            )
            print("")
            print(f"Git  :  {GIT_REPO_ORIG}")
            if _doExitWith is None:
                _doExitWith = 0

        if _doExitWith is not None:
            sys.exit(_doExitWith)

    ###########################################
    #
    #
    depthLimit = None
    dirpath = nonParamArgs[0] if (len(nonParamArgs) >= 1) else "."
    pathReview = PathReviewEntry(dirpath, "", styling, depthLimitRemaining=depthLimit)

    generated_summary = pathReview.dump()
    for x in generated_summary:
        print(f"{x}")


########################################
#
#
class PathReviewStyling:

    def __init__(self, styleText: str = "Tree"):
        self.isStyle = styleText
        self.filterFilenames = ["__pycache__", ".git", ".DS_Store", "_skip_*"]
        self.followLinks = False

    def isTreeStyle(self) -> bool:
        return self.isStyle.lower() == "tree"

    def isFlatStyle(self) -> bool:
        return self.isStyle.lower() == "flat"

    def asObj(self) -> dict:
        return {
            "formatRev": 1,
            "style": self.isStyle.upper(),
            "links": "FOLLOW" if self.followLinks else "NOFOLLOW",
            "filterFilenames": self.filterFilenames,
        }

    def styleCode(self) -> str:
        return json.dumps(self.asObj())

    def doFollowLinks(self) -> bool:
        return self.followLinks

    def shouldFilterFile(self, path: str, fname: str) -> bool:
        for pattern in self.filterFilenames:
            if fnmatch.fnmatch(fname, pattern):
                return True
        return False

    def dumpStylingInfo(self, prefix: str = "# ") -> list[str]:
        outputLines = []
        outputLines.append(
            f"{prefix}Filtering filenames: " + ", ".join(self.filterFilenames)
        )
        outputLines.append(f"{prefix}")
        outputLines.append(f"{prefix}Style              : {self.isStyle}")
        outputLines.append(f"{prefix}")
        if self.isTreeStyle():
            outputLines.append(
                f"{prefix}Format         : [attributes] | [hash] [TreePrefix]── [filename]"
            )
        else:  # if (self.isFlatStyle()):
            outputLines.append(f"{prefix}Format         : [attributes] | [hash] [path]")

        outputLines.append(
            f"{prefix}                 (Hash has a '*' suffix if error and '?' if not fully reviewed)"
        )

        return outputLines


class PathReviewEntry:

    def calculate(self):
        self.depthLimitRemaining
        path = self.path()
        # |x|print(f"!!!!: calculate({path}, depthLimitRemaining={self.depthLimitRemaining})")

        self.attr = ""
        self.containsError = False
        self.deepestLevelReached = self.depth
        try:
            # Get the file attributes
            stat_info = os.stat(path)
            st_mode = stat_info.st_mode
            self.attr = oct(st_mode)[2:].rjust(7, "_")

            for x in ["__40", "_100"]:
                if self.attr.startswith(x):
                    self.attr = "_" * len(x) + self.attr[len(x) :]
            if self.attr.startswith("____"):
                # Convert to rwx format for better readability

                self.attr = ""
                for n in [1, 2, 3]:
                    self.attr = (
                        "".join(
                            [
                                "r" if st_mode & os.R_OK else "-",
                                "w" if st_mode & os.W_OK else "-",
                                "x" if st_mode & os.X_OK else "-",
                            ]
                        )
                        + self.attr
                    )
                    st_mode = st_mode >> 3
                self.attr = "~" + self.attr
        except FileNotFoundError:
            self.attr = "Missing"
            self.containsError = True
            Utils.log_warning(f"File {path} does not exist")
        except Exception as e:
            self.attr = "XXXXXXX"
            self.containsError = True
            Utils.log_error(
                f"Unable to get file stats of {path}. An error occurred: {e}"
            )

        #
        # Create:
        # hash, contentsIsReviewed, attr, childEntries
        #
        self.hash = ""
        self.contentsIsReviewed = True
        self.childEntries = []

        self.suffix_note = ""
        string_to_hash = ""
        first_attr_char = "-"
        hashPrefix = ""
        try:
            isDir = os.path.isdir(path)
            isLink = os.path.islink(path)
            isFile = os.path.isfile(path)

            isHashed = False

            if isLink:
                first_attr_char = "l"
                hashPrefix = "link_"
                x = os.readlink(path)

                if not self.STYLING.doFollowLinks():
                    self.hash = Utils.md5_of_string(x)
                elif isDir:
                    hashPrefix = f"Linked[dir]_"
                elif isFile:
                    hashPrefix = f"Linked[file]_"
                else:
                    hashPrefix = f"Linked"

                self.suffix_note = f" → {x}{'/' if isDir else ''}"

            if self.hash != "":
                pass
            elif isFile:
                self.hash = Utils.md5_of_file(path)
            elif isDir:
                if hashPrefix == "":
                    hashPrefix = f"dir_"

                first_attr_char = "d" if not isLink else "D"

                self.fname_noPath = (
                    (self.fname_noPath.removesuffix("/") + "/")
                    if self.fname_noPath
                    else "./"
                )
                if (self.depthLimitRemaining is not None) and (
                    self.depthLimitRemaining <= 0
                ):
                    self.contentsIsReviewed = False
                else:
                    for x in sorted(os.listdir(path)):
                        if self.STYLING.shouldFilterFile(path, x):
                            Utils.log_msg(
                                f"Skipping filtered filename: {x:<40}  in {path}"
                            )
                        else:
                            entry = PathReviewEntry(
                                path,
                                x,
                                self.STYLING,
                                self.depth + 1,
                                (
                                    None
                                    if self.depthLimitRemaining is None
                                    else self.depthLimitRemaining - 1
                                ),
                            )
                            if entry.containsError:
                                self.containsError = True
                            if not entry.contentsIsReviewed:
                                self.contentsIsReviewed = False
                            string_to_hash += "[" + entry.attr + ":" + entry.hash + "]"
                            self.childEntries.append(entry)
                            if entry.deepestLevelReached + 1 > self.deepestLevelReached:
                                self.deepestLevelReached = entry.deepestLevelReached + 1
                    if len(self.childEntries) == 0:
                        self.hash += "_0_entries"

            else:
                self.hash = f"unknown_type"
                self.contentsIsReviewed = True

        except Exception as e:
            Utils.log_error(f"Error processing path '{path}': {e}", isFatal=False)
            self.containsError = True
            self.hash = f"unable_to_read"

        if string_to_hash != "":
            # Utils.log_msg(f"Hashing string for {path}: {string_to_hash}")
            self.hash = Utils.md5_of_string(string_to_hash)
        if self.attr.startswith("~"):
            self.attr = first_attr_char + self.attr[1:]
        self.hash = hashPrefix + self.hash

    def __init__(
        self,
        parentPath: str,
        fname_noPath: str,
        STYLING: PathReviewStyling | None = None,
        depth: int = 0,
        depthLimitRemaining: int | None = None,
    ):
        self.parentPath = parentPath
        self.fname_noPath = fname_noPath

        self.STYLING = STYLING if STYLING is not None else PathReviewStyling()

        self.depth = depth
        self.depthLimitRemaining = depthLimitRemaining

        ##############
        # These will be updated in the 'calculate()' method - the are listed here for completeness
        self.childEntries = []
        self.hash = ""
        self.attr = ""
        self.containsError = False
        self.contentsIsReviewed = False
        self.suffix_note = ""
        self.deepestLevelReached = 0

        self.calculate()

    def dump(
        self,
        isRecursive: bool = True,
        isLastHistory: list[bool] = [],
        isLast: bool = True,
        withHeaderAtTop: bool = True,
    ) -> list[str]:
        outputLines = []

        if withHeaderAtTop and (len(isLastHistory) == 0):
            print(f"[FORMAT: {self.STYLING.styleCode()}]")
            print("# ")
            print("# Review of directory: " + self.path(giveFullPath=True))

            _txt = ""
            if self.depthLimitRemaining is not None:
                _txt = f" (limited to depth {self.depthLimitRemaining})"
            if not self.contentsIsReviewed:
                _txt += " -- not fully reviewed"

            print(f"# Max depth found    : {self.deepestLevelReached}{_txt}")

            for x in self.STYLING.dumpStylingInfo():
                print(x)
            print("# ")

        outputLines.append(self.asOutputLine(isLastHistory, isLast))
        if (
            isRecursive
            and (self.childEntries is not None)
            and (len(self.childEntries) > 0)
        ):
            n = len(self.childEntries)
            for i, child in enumerate(self.childEntries):
                isLastChild = i == n - 1
                outputLines.extend(
                    child.dump(
                        isRecursive,
                        isLastHistory + [isLast],
                        isLastChild,
                        withHeaderAtTop=False,
                    )
                )

        return outputLines

    def hasCompletelyReviewedContents(self) -> bool:
        if not self.contentsIsReviewed:
            return False
        if len(self.childEntries) > 0:
            for child in self.childEntries:
                if not child.hasCompletelyReviewedContents():
                    return False
        return True

    def asOutputLine(self, isLastHistory: list[bool] = [], isLast: bool = False) -> str:
        txt = f"{self.attr[:10]:_<10} | {self.hash[:32]:_<32}"
        if self.containsError:
            txt += "*"
        elif not self.contentsIsReviewed:
            txt += "?"
        else:
            txt += " "
        if self.STYLING.isTreeStyle():
            treePrefix = "".join(
                [("    " if item else "│   ") for item in isLastHistory]
            )

            if isLast:
                treePrefix += "└──"
            else:
                treePrefix += "├──"
            txt += f" {treePrefix} {self.path(giveFullPath=False)}"
        else:
            txt += f" {self.path(giveFullPath=True)}"

        txt += self.suffix_note

        return txt

    def path(self, giveFullPath: bool = True) -> str:
        if giveFullPath:
            txt = os.path.join(self.parentPath, self.fname_noPath).removeprefix("./")
            if txt.endswith("/./"):
                txt = txt.removesuffix("./")
        else:
            txt = self.fname_noPath

        return txt if txt else "."


class Utils:

    @staticmethod
    def log_msg(msgMayBeMultiline: str, prefixOnFirstLine: str = "", icon: str = "ℹ️  "):
        Utils._log_lines(msgMayBeMultiline, prefixOnFirstLine, icon)

    @staticmethod
    def log_warning(msgMayBeMultiline: str):
        Utils._log_lines(msgMayBeMultiline, "Warning: ", "⚠️  ")

    @staticmethod
    def log_error(msg: str, isFatal: bool = False):
        if isFatal:
            Utils._log_lines(msg, "Fatal Error: ", "❌  ")
            sys.exit(1)
        else:
            Utils._log_lines(msg, "Error: ", "⚠️  ")

    @staticmethod
    def _log_lines(
        msgMayBeMultiline: str, prefixOnFirstLine: str = "", prefixOnEveryLine: str = ""
    ):

        for i, line in enumerate(msgMayBeMultiline.splitlines()):
            if i == 0:
                sys.stderr.write(f"{prefixOnEveryLine}{prefixOnFirstLine}{line}\n")
            else:
                sys.stderr.write(
                    f"{prefixOnEveryLine}{' ' * len(prefixOnFirstLine)}{line}\n"
                )

    @staticmethod
    def FatalError(msg: str) -> NoReturn:
        Utils.log_error(msg, isFatal=True)
        sys.exit(1)

    @staticmethod
    def md5_of_file(fname: str) -> str:
        with open(fname, "rb") as file:
            raw_bytes = file.read()
            md5hash_value = hashlib.md5(raw_bytes).hexdigest()
        return md5hash_value

    @staticmethod
    def md5_of_string(txt: str) -> str:
        raw_bytes = txt.encode("utf-8")
        md5hash_value = hashlib.md5(raw_bytes).hexdigest()
        return md5hash_value


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        # Handle broken pipe error gracefully (e.g., when piping output to 'head')
        sys.exit(0)
