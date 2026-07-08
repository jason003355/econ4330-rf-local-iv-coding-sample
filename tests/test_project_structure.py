import unittest
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ProjectStructureTests(unittest.TestCase):
    def test_expected_files_exist(self):
        expected = [
            "README.md",
            "DESCRIPTION",
            ".gitignore",
            "R/dml_iv.R",
            "R/clustering.R",
            "R/plots.R",
            "R/utils.R",
            "scripts/make_sample_data.R",
            "scripts/run_analysis.R",
            "docs/data_dictionary.md",
            "docs/method_note.md",
        ]
        missing = [path for path in expected if not (ROOT / path).exists()]
        self.assertFalse(missing, f"Missing expected files: {missing}")

    def test_no_original_absolute_paths_in_source(self):
        user_path = re.compile(r"[A-Za-z]:[/\\]Users[/\\][^/\\]+[/\\]")
        source_files = list((ROOT / "R").glob("*.R")) + list((ROOT / "scripts").glob("*.R"))
        for source in source_files:
            text = source.read_text(encoding="utf-8")
            self.assertIsNone(user_path.search(text), f"Found Windows user path in {source}")

    def test_readme_mentions_data_restrictions(self):
        text = (ROOT / "README.md").read_text(encoding="utf-8").lower()
        self.assertIn("licensed", text)
        self.assertIn("wrds", text)
        self.assertIn("not included", text)


if __name__ == "__main__":
    unittest.main()
