int f(int *p, int *q)
/*@
requires
    has_alloc_id(p);
    has_alloc_id(q);
    (u64) p != (u64) q;
ensures
    return == 0i32;
@*/
{
    return p == q;
}

int main()
{
    int x = 0;
    int y = 1;
    f(&x, &y);
}
