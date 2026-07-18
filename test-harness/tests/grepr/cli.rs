use assert_cmd::Command;
use predicates::prelude::*;
use rand::{distributions::Alphanumeric, Rng};
use std::{fs, path::Path};
use sys_info::os_type;

type TestResult = Result<(), Box<dyn std::error::Error>>;

const PRG: &str = "grepr";

macro_rules! command {
    () => {
        Command::new("dune").arg("exec").arg(PRG).arg("--")
    };
}
const BUSTLE: &str = "tests/grepr/inputs/bustle.txt";
const EMPTY: &str = "tests/grepr/inputs/empty.txt";
const FOX: &str = "tests/grepr/inputs/fox.txt";
const NOBODY: &str = "tests/grepr/inputs/nobody.txt";
const INPUTS_DIR: &str = "tests/grepr/inputs";

// --------------------------------------------------
fn gen_bad_file() -> String {
    loop {
        let filename: String = rand::thread_rng()
            .sample_iter(&Alphanumeric)
            .take(7)
            .map(char::from)
            .collect();

        if fs::metadata(&filename).is_err() {
            return filename;
        }
    }
}

// --------------------------------------------------
#[test]
fn dies_no_args() -> TestResult {
    command!()
        .assert()
        .failure()
        .stderr(predicate::str::contains("USAGE"));
    Ok(())
}

// --------------------------------------------------
#[test]
fn dies_bad_pattern() -> TestResult {
    command!()
        .args(&["*foo", FOX])
        .assert()
        .failure()
        .stderr(predicate::str::contains("Invalid pattern \"*foo\""));
    Ok(())
}

// --------------------------------------------------
#[test]
fn warns_bad_file() -> TestResult {
    let bad = gen_bad_file();
    let expected = format!("{}: .* [(]os error 2[)]", bad);
    command!()
        .args(&["foo", &bad])
        .assert()
        .stderr(predicate::str::is_match(expected)?);
    Ok(())
}

// --------------------------------------------------
fn run(args: &[&str], expected_file: &str) -> TestResult {
    let windows_file = format!("{}.windows", expected_file);
    let expected_file = if os_type().unwrap() == "Windows"
        && Path::new(&windows_file).is_file()
    {
        &windows_file
    } else {
        expected_file
    };

    let expected = fs::read_to_string(&expected_file)?;

    command!()
        .args(args)
        .assert()
        .stdout(expected);
    Ok(())
}

// --------------------------------------------------
#[test]
fn empty_file() -> TestResult {
    run(&["foo", EMPTY], "tests/grepr/expected/empty.foo")
}

// --------------------------------------------------
#[test]
fn empty_regex() -> TestResult {
    run(&["", FOX], "tests/grepr/expected/empty_regex.fox.txt")
}

// --------------------------------------------------
#[test]
fn bustle_capitalized() -> TestResult {
    run(
        &["The", BUSTLE],
        "tests/grepr/expected/bustle.txt.the.capitalized",
    )
}

// --------------------------------------------------
#[test]
fn bustle_lowercase() -> TestResult {
    run(&["the", BUSTLE], "tests/grepr/expected/bustle.txt.the.lowercase")
}

// --------------------------------------------------
#[test]
fn bustle_insensitive() -> TestResult {
    run(
        &["--insensitive", "the", BUSTLE],
        "tests/grepr/expected/bustle.txt.the.lowercase.insensitive",
    )
}

// --------------------------------------------------
#[test]
fn nobody() -> TestResult {
    run(&["nobody", NOBODY], "tests/grepr/expected/nobody.txt")
}

// --------------------------------------------------
#[test]
fn nobody_insensitive() -> TestResult {
    run(
        &["-i", "nobody", NOBODY],
        "tests/grepr/expected/nobody.txt.insensitive",
    )
}

// --------------------------------------------------
#[test]
fn multiple_files() -> TestResult {
    run(
        &["The", BUSTLE, EMPTY, FOX, NOBODY],
        "tests/grepr/expected/all.the.capitalized",
    )
}

// --------------------------------------------------
#[test]
fn multiple_files_insensitive() -> TestResult {
    run(
        &["-i", "the", BUSTLE, EMPTY, FOX, NOBODY],
        "tests/grepr/expected/all.the.lowercase.insensitive",
    )
}

// --------------------------------------------------
#[test]
fn recursive() -> TestResult {
    run(
        &["--recursive", "dog", INPUTS_DIR],
        "tests/grepr/expected/dog.recursive",
    )
}

// --------------------------------------------------
#[test]
fn recursive_insensitive() -> TestResult {
    run(
        &["-ri", "then", INPUTS_DIR],
        "tests/grepr/expected/the.recursive.insensitive",
    )
}

// --------------------------------------------------
#[test]
fn sensitive_count_capital() -> TestResult {
    run(
        &["--count", "The", BUSTLE],
        "tests/grepr/expected/bustle.txt.the.capitalized.count",
    )
}

// --------------------------------------------------
#[test]
fn sensitive_count_lower() -> TestResult {
    run(
        &["--count", "the", BUSTLE],
        "tests/grepr/expected/bustle.txt.the.lowercase.count",
    )
}

// --------------------------------------------------
#[test]
fn insensitive_count() -> TestResult {
    run(
        &["-ci", "the", BUSTLE],
        "tests/grepr/expected/bustle.txt.the.lowercase.insensitive.count",
    )
}

// --------------------------------------------------
#[test]
fn nobody_count() -> TestResult {
    run(&["-c", "nobody", NOBODY], "tests/grepr/expected/nobody.txt.count")
}

// --------------------------------------------------
#[test]
fn nobody_count_insensitive() -> TestResult {
    run(
        &["-ci", "nobody", NOBODY],
        "tests/grepr/expected/nobody.txt.insensitive.count",
    )
}

// --------------------------------------------------
#[test]
fn sensitive_count_multiple() -> TestResult {
    run(
        &["-c", "The", BUSTLE, EMPTY, FOX, NOBODY],
        "tests/grepr/expected/all.the.capitalized.count",
    )
}

// --------------------------------------------------
#[test]
fn insensitive_count_multiple() -> TestResult {
    run(
        &["-ic", "the", BUSTLE, EMPTY, FOX, NOBODY],
        "tests/grepr/expected/all.the.lowercase.insensitive.count",
    )
}

// --------------------------------------------------
#[test]
fn warns_dir_not_recursive() -> TestResult {
    let stdout = "tests/grepr/inputs/fox.txt:\
        The quick brown fox jumps over the lazy dog.";
    command!()
        .args(&["fox", INPUTS_DIR, FOX])
        .assert()
        .stderr(predicate::str::contains("tests/grepr/inputs is a directory"))
        .stdout(predicate::str::contains(stdout));
    Ok(())
}

// --------------------------------------------------
#[test]
fn stdin() -> TestResult {
    let input = fs::read_to_string(BUSTLE)?;
    let expected =
        fs::read_to_string("tests/grepr/expected/bustle.txt.the.capitalized")?;

    command!()
        .arg("The")
        .write_stdin(input)
        .assert()
        .stdout(expected);
    Ok(())
}

// --------------------------------------------------
#[test]
fn stdin_insensitive_count() -> TestResult {
    let files = &[BUSTLE, EMPTY, FOX, NOBODY];

    let mut input = String::new();
    for file in files {
        input += &fs::read_to_string(file)?;
    }

    let expected_file =
        "tests/grepr/expected/the.recursive.insensitive.count.stdin";
    let expected = fs::read_to_string(expected_file)?;

    command!()
        .args(&["-ci", "the", "-"])
        .write_stdin(input)
        .assert()
        .stdout(expected);
    Ok(())
}
