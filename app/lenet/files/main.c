#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "kinpira.h"
#include "types.h"
#include "util.h"
#include "peta.h"

#include "lenet.h"

#include "data/image.h"
#include "data/full3_tru.h"

int main(void)
{
  s16 label[LABEL];
  s16 *input, *output;

  LeNet_init(&input, &output);

  setbuf(stdout, NULL);
  printf("\033[2J");
  puts("### newLenet @ 42\n");

  memmove(input, image, sizeof(s16)*N_IN*ISIZE*ISIZE);
  LeNet_eval();
  memmove(label, output, sizeof(s16)*LABEL);

  print_result(label, LABEL);
  assert_rep(label, full3_tru, LABEL);
  puts("assert ok");

  LeNet_exit();

  return 0;
}

