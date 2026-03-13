/// Handles the result based on the pop status.
/// 
/// If `didpop` is true, the function returns immediately.
/// Otherwise, it processes the `result`.
/// 
/// Parameters:
/// - `didpop`: A boolean indicating whether a pop action occurred.
/// - `result`: The result to be processed if `didpop` is false.
popFunc({required bool didpop, required var result}) {
  if (didpop) {
    return;
  } else {
    result;
  }
}