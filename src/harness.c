/* Fuzzing harness for libpng. 
 * 
 * AFL++ will pass each test input as a file path on the command line.ù
 * The program opens the file and feed it to libpng. Returns 0 if libpng doesn't crash.
 * To be filled in after the Dockerfile and build steps work.
 */