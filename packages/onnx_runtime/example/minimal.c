#include <stdio.h>
#include <onnxruntime_c_api.h>

int main(void) {
    puts(OrtGetApiBase()->GetVersionString());
    return 0;
}
