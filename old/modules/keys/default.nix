{
  mmazzanti = {
    lambda = builtins.readFile ./lambda.pub.ssh;
    iota = builtins.readFile ./iota.pub.ssh;
    beta = builtins.readFile ./beta.pub.ssh;
  };
}
