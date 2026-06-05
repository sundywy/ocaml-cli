use assert_cmd::Command;
use predicates::prelude::*;
use std::fs;

type TestResult = Result<(), Box<dyn std::error::Error>>;

macro_rules! command {
    ($prg:literal) => {
        Command::new("dune").arg("exec").arg($prg).arg("--")
    };
}

// --------------------------------------------------
#[test]
fn dies_no_args() -> TestResult {
    command!("echor")
        .assert()
        .failure()
        .stderr(predicate::str::contains("Usage"));
    Ok(())
}

// --------------------------------------------------
fn run(args: &[&str], expected_file: &str) -> TestResult {
    let expected = fs::read_to_string(expected_file)?;
    command!("echor")
        .args(args)
        .assert()
        .success()
        .stdout(expected);
    Ok(())
}

// --------------------------------------------------
#[test]
fn hello1() -> TestResult {
    run(&["Hello there"], "tests/echor/expected/hello1.txt")
}

// --------------------------------------------------
#[test]
fn hello2() -> TestResult {
    run(&["Hello", "there"], "tests/echor/expected/hello2.txt")
}

// --------------------------------------------------
#[test]
fn hello1_no_newline() -> TestResult {
    run(&["Hello  there", "-n"], "tests/echor/expected/hello1.n.txt")
}

// --------------------------------------------------
#[test]
fn hello2_no_newline() -> TestResult {
    run(
        &["-n", "Hello", "there"],
        "tests/echor/expected/hello2.n.txt",
    )
}
