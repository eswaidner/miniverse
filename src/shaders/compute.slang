

[shader("compute")]
[numthreads(8,8,1)]
void compMain(uint3 globalId: SV_DispatchThreadID, uint3 localId: SV_GroupThreadID) {

}