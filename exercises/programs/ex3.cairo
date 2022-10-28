// Perform and log output of simple arithmetic operations
func simple_math() {
   // adding 13 +  14
   tempvar a = 13+14;
   // multiplying 3 * 6
   tempvar b = 3*6;
   // dividing 6 by 2
   tempvar c = 6/2;
   // dividing 70 by 2
   tempvar d = 70/2;
   // dividing 7 by 2
   tempvar e = 7/2;
   %{
   print(ids.a)
   print(ids.b)
   print(ids.c)
   print(ids.d)
   print(ids.e)
   %}
    return ();
}
