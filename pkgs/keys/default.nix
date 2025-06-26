{
  ssh = {
    lambda = builtins.readFile ./ssh/lambda.pub.ssh;
    beta = builtins.readFile ./ssh/beta.pub.ssh;
    framework = builtins.readFile ./ssh/framework.pub.ssh;
  };
  ca = {
    crt = builtins.readFile ./ca/mmazzanti.crt;
  };
}
