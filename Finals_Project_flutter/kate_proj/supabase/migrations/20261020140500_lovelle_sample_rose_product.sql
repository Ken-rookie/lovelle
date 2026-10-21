do $$
declare
  rose_product_id public.products.id%type;
begin
  select id
  into rose_product_id
  from public.products
  where lower(name) = lower('Lovelle Rose Gift')
  limit 1;

  if rose_product_id is null then
    insert into public.products (
      name,
      description,
      price,
      image_url,
      stock_quantity,
      is_available,
      is_featured,
      is_rose_gift,
      category_id
    )
    values (
      'Lovelle Rose Gift',
      'A lovely rose gift. Choose a fresh rose or an artificial rose at checkout. Both styles are the same price.',
      499.00,
      'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=1200&q=85',
      20,
      true,
      true,
      true,
      (
        select id
        from public.categories
        where is_active is true
          and (name ilike '%flower%' or name ilike '%rose%')
        order by name
        limit 1
      )
    )
    returning id into rose_product_id;
  else
    update public.products
    set description = 'A lovely rose gift. Choose a fresh rose or an artificial rose at checkout. Both styles are the same price.',
        price = 499.00,
        image_url = coalesce(
          nullif(trim(image_url), ''),
          'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=1200&q=85'
        ),
        stock_quantity = greatest(stock_quantity, 20),
        is_available = true,
        is_featured = true,
        is_rose_gift = true
    where id = rose_product_id;
  end if;
end
$$;
