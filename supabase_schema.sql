-- E-commerce schema for Supabase
-- Run this file in the Supabase SQL editor on a new project.

create extension if not exists pgcrypto;

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text not null default '',
  phone text not null default '',
  address text not null default '',
  country text not null default '',
  state text not null default '',
  city text not null default '',
  role text not null default 'Buyer' check (role in ('Buyer', 'Seller')),
  created_at timestamptz not null default now(),
  constraint users_name_key unique (name)
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (
    id, email, name, phone, address, country, state, city, role
  ) values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'address', ''),
    coalesce(new.raw_user_meta_data->>'country', ''),
    coalesce(new.raw_user_meta_data->>'state', ''),
    coalesce(new.raw_user_meta_data->>'city', ''),
    case
      when new.raw_user_meta_data->>'role' = 'Seller' then 'Seller'
      else 'Buyer'
    end
  )
  on conflict (id) do update set
    email = excluded.email,
    name = excluded.name,
    phone = excluded.phone,
    address = excluded.address,
    country = excluded.country,
    state = excluded.state,
    city = excluded.city,
    role = excluded.role;
  return new;
exception when unique_violation then
  insert into public.users (
    id, email, name, phone, address, country, state, city, role
  ) values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', '') || '_' || substr(md5(random()::text), 1, 4),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'address', ''),
    coalesce(new.raw_user_meta_data->>'country', ''),
    coalesce(new.raw_user_meta_data->>'state', ''),
    coalesce(new.raw_user_meta_data->>'city', ''),
    case
      when new.raw_user_meta_data->>'role' = 'Seller' then 'Seller'
      else 'Buyer'
    end
  )
  on conflict (id) do update set
    email = excluded.email,
    name = excluded.name,
    phone = excluded.phone,
    address = excluded.address,
    country = excluded.country,
    state = excluded.state,
    city = excluded.city,
    role = excluded.role;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Backfill profile rows for Auth users that existed before this schema.
insert into public.users (id, email, name, phone, address, country, state, city, role)
select
  id,
  email,
  coalesce(raw_user_meta_data->>'name', ''),
  coalesce(raw_user_meta_data->>'phone', ''),
  coalesce(raw_user_meta_data->>'address', ''),
  coalesce(raw_user_meta_data->>'country', ''),
  coalesce(raw_user_meta_data->>'state', ''),
  coalesce(raw_user_meta_data->>'city', ''),
  case when raw_user_meta_data->>'role' = 'Seller' then 'Seller' else 'Buyer' end
from auth.users
on conflict (id) do nothing;

create table public.product (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text,
  category text not null default 'General',
  subcategory text not null default 'General',
  price numeric(12,2) not null check (price > 0),
  discount_price numeric(12,2),
  quantity integer not null default 0 check (quantity >= 0),
  img_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint product_discount_check check (
    discount_price is null or (discount_price >= 0 and discount_price < price)
  )
);

alter table public.product
  add column if not exists subcategory text not null default 'General';

create table public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.product(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text not null check (char_length(trim(comment)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, user_id)
);

create table public.product_likes (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.product(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create table public.cart_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.product(id) on delete cascade,
  quantity integer not null default 1 check (quantity > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, product_id)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_name text not null,
  customer_email text not null,
  customer_phone text not null,
  address text not null,
  country text not null,
  state text not null,
  city text not null,
  total_price numeric(12,2) not null default 0 check (total_price >= 0),
  payment_method text not null default 'cash_on_delivery' check (
    payment_method in ('cash_on_delivery', 'razorpay')
  ),
  payment_status text not null default 'pending' check (
    payment_status in ('pending', 'paid', 'failed', 'refunded')
  ),
  razorpay_order_id text,
  razorpay_payment_id text,
  status text not null default 'pending' check (
    status in ('pending', 'paid', 'packed', 'shipped', 'out for delivery', 'delivered', 'cancelled')
  ),
  -- Exact date and time when the buyer placed the order.
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.product(id) on delete restrict,
  seller_id uuid not null references auth.users(id) on delete restrict,
  product_name text not null,
  product_image text,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  quantity integer not null check (quantity > 0),
  item_total numeric(12,2) not null check (item_total >= 0),
  created_at timestamptz not null default now()
);

-- Safe migration for databases where orders already exists.
alter table public.orders
  add column if not exists payment_method text not null default 'cash_on_delivery';
alter table public.orders
  add column if not exists payment_status text not null default 'pending',
  add column if not exists razorpay_order_id text,
  add column if not exists razorpay_payment_id text;

alter table public.orders
  drop constraint if exists orders_payment_method_check,
  drop constraint if exists orders_payment_status_check,
  drop constraint if exists orders_status_check;
alter table public.orders
  add constraint orders_payment_method_check
    check (payment_method in ('cash_on_delivery', 'razorpay')),
  add constraint orders_payment_status_check
    check (payment_status in ('pending', 'paid', 'failed', 'refunded')),
  add constraint orders_status_check
    check (status in ('pending', 'paid', 'packed', 'shipped', 'out for delivery', 'delivered', 'cancelled'));

create unique index if not exists orders_razorpay_order_id_key
  on public.orders(razorpay_order_id) where razorpay_order_id is not null;
create unique index if not exists orders_razorpay_payment_id_key
  on public.orders(razorpay_payment_id) where razorpay_payment_id is not null;

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  order_id uuid references public.orders(id) on delete cascade,
  title text not null,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.return_requests (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null unique references public.order_items(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'requested' check (
    status in (
      'requested', 'pickup', 'checked', 'replacement packed',
      'replacement shipped', 'shipped', 'payment done', 'rejected'
    )
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index product_user_id_idx on public.product(user_id);
create index product_category_idx on public.product(category);
create index product_reviews_product_id_idx on public.product_reviews(product_id);
create index product_likes_product_id_idx on public.product_likes(product_id);
create index cart_items_user_id_idx on public.cart_items(user_id);
create index order_items_order_id_idx on public.order_items(order_id);
create index order_items_seller_id_idx on public.order_items(seller_id);
create index orders_user_id_idx on public.orders(user_id);
create index notifications_user_id_idx on public.notifications(user_id);
create index return_requests_seller_id_idx on public.return_requests(seller_id);
create index return_requests_buyer_id_idx on public.return_requests(buyer_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  product_id uuid references public.product(id) on delete set null,
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint messages_different_users check (sender_id <> receiver_id)
);

create index messages_sender_receiver_idx
  on public.messages(sender_id, receiver_id, created_at desc);
create index messages_receiver_sender_idx
  on public.messages(receiver_id, sender_id, created_at desc);

create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  description text,
  discount_type text not null check (discount_type in ('percentage', 'fixed')),
  discount_value numeric(12,2) not null check (discount_value > 0),
  min_order_amount numeric(12,2) not null default 0 check (min_order_amount >= 0),
  max_discount numeric(12,2),
  total_quantity integer not null check (total_quantity >= 0),
  used_quantity integer not null default 0 check (used_quantity >= 0),
  is_active boolean not null default true,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.coupon_redemptions (
  id uuid primary key default gen_random_uuid(),
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  redeemed_at timestamptz not null default now(),
  unique (coupon_id, user_id)
);

create table if not exists public.payment_webhook_events (
  event_id text primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'processed' check (status in ('processed', 'ignored'))
);

create table if not exists public.user_fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  device_info text,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.push_notification_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  order_id uuid references public.orders(id) on delete cascade,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  is_sent boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.users enable row level security;
alter table public.product enable row level security;
alter table public.product_reviews enable row level security;
alter table public.product_likes enable row level security;
alter table public.cart_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.notifications enable row level security;
alter table public.return_requests enable row level security;
alter table public.messages enable row level security;
alter table public.coupons enable row level security;
alter table public.coupon_redemptions enable row level security;
alter table public.payment_webhook_events enable row level security;
alter table public.user_fcm_tokens enable row level security;
alter table public.push_notification_logs enable row level security;

create policy "Authenticated users can read active coupons"
  on public.coupons for select to authenticated using (is_active = true);
create policy "Users can read own coupon redemptions"
  on public.coupon_redemptions for select to authenticated using (auth.uid() = user_id);
create policy "Users can manage own tokens"
  on public.user_fcm_tokens for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "Users can read own push logs"
  on public.push_notification_logs for select to authenticated
  using (auth.uid() = user_id);
revoke all on public.payment_webhook_events from public, anon, authenticated;
grant all on public.payment_webhook_events to service_role;

create policy "Authenticated users can read profiles"
on public.users for select to authenticated using (true);
create policy "Users can update own profile"
on public.users for update to authenticated
using (auth.uid() = id) with check (auth.uid() = id);

create policy "Authenticated users can read products"
on public.product for select to authenticated using (true);
create policy "Sellers can create products"
on public.product for insert to authenticated
with check (auth.uid() = user_id);
create policy "Sellers can update own products"
on public.product for update to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Sellers can delete own products"
on public.product for delete to authenticated
using (auth.uid() = user_id);

create policy "Authenticated users can read product reviews"
on public.product_reviews for select to authenticated using (true);

create policy "Buyers can create reviews for purchased products"
on public.product_reviews for insert to authenticated
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.orders o
    join public.order_items oi on oi.order_id = o.id
    where o.user_id = auth.uid()
      and oi.product_id = product_reviews.product_id
  )
);

create policy "Users can update own product reviews"
on public.product_reviews for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete own product reviews"
on public.product_reviews for delete to authenticated
using (auth.uid() = user_id);

create policy "Users can read own product likes"
on public.product_likes for select to authenticated
using (auth.uid() = user_id);

create policy "Users can like products"
on public.product_likes for insert to authenticated
with check (auth.uid() = user_id);

create policy "Users can remove own product likes"
on public.product_likes for delete to authenticated
using (auth.uid() = user_id);

create policy "Users can read own cart"
on public.cart_items for select to authenticated using (auth.uid() = user_id);
create policy "Users can insert own cart"
on public.cart_items for insert to authenticated
with check (auth.uid() = user_id);
create policy "Users can update own cart"
on public.cart_items for update to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users can delete own cart"
on public.cart_items for delete to authenticated
using (auth.uid() = user_id);

create policy "Buyers can read own orders"
on public.orders for select to authenticated using (auth.uid() = user_id);
create policy "Buyers can create own orders"
on public.orders for insert to authenticated
with check (auth.uid() = user_id);

create policy "Buyers can read own order items"
on public.order_items for select to authenticated
using (exists (
  select 1 from public.orders o
  where o.id = order_items.order_id and o.user_id = auth.uid()
));
create policy "Sellers can read their order items"
on public.order_items for select to authenticated
using (auth.uid() = seller_id);

create policy "Users can read own notifications"
on public.notifications for select to authenticated
using (auth.uid() = user_id);

-- This helper prevents recursive RLS policies when sellers read an order.
create or replace function public.seller_has_order(target_order_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.order_items oi
    where oi.order_id = target_order_id and oi.seller_id = auth.uid()
  );
$$;
revoke all on function public.seller_has_order(uuid) from public;
grant execute on function public.seller_has_order(uuid) to authenticated;

create policy "Sellers can read related orders"
on public.orders for select to authenticated
using (public.seller_has_order(id));
create policy "Sellers can update related orders"
on public.orders for update to authenticated
using (public.seller_has_order(id))
with check (status in ('pending', 'packed', 'shipped', 'out for delivery', 'delivered', 'cancelled'));

create policy "Sellers can create buyer notifications"
on public.notifications for insert to authenticated
with check (public.seller_has_order(order_id));
create policy "Users can update own notifications"
on public.notifications for update to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users can delete own notifications"
on public.notifications for delete to authenticated
using (auth.uid() = user_id);

create policy "Buyers can create own return requests"
on public.return_requests for insert to authenticated
with check (auth.uid() = buyer_id);
create policy "Buyers can read own return requests"
on public.return_requests for select to authenticated
using (auth.uid() = buyer_id);
create policy "Sellers can read return requests"
on public.return_requests for select to authenticated
using (auth.uid() = seller_id);
create policy "Sellers can update return requests"
on public.return_requests for update to authenticated
using (auth.uid() = seller_id)
with check (
  auth.uid() = seller_id
  and status in (
    'requested', 'pickup', 'checked', 'replacement packed',
    'replacement shipped', 'shipped', 'payment done', 'rejected'
  )
);

-- Users can read messages where they are the sender or receiver (Required for Supabase Realtime streaming)
create policy "Users can read own messages"
on public.messages for select to authenticated
using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "Users can mark received messages read"
on public.messages for update to authenticated
using (auth.uid() = receiver_id)
with check (auth.uid() = receiver_id);

create or replace function public.send_message(
  p_receiver_id uuid,
  p_order_id uuid,
  p_product_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender_id uuid := auth.uid();
  v_message record;
begin
  if v_sender_id is null then
    raise exception 'You must be logged in to send a message';
  end if;

  if p_body is null or trim(p_body) = '' then
    raise exception 'Message body cannot be empty';
  end if;

  if not exists (
    select 1
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where (
      (o.user_id = v_sender_id and oi.seller_id = p_receiver_id)
      or (o.user_id = p_receiver_id and oi.seller_id = v_sender_id)
    )
    and (p_order_id is null or oi.order_id = p_order_id)
  ) then
    raise exception 'You are not allowed to send a message to this user';
  end if;

  insert into public.messages (
    sender_id, receiver_id, order_id, product_id, body
  ) values (
    v_sender_id, p_receiver_id, p_order_id, p_product_id, trim(p_body)
  ) returning * into v_message;

  return row_to_json(v_message)::jsonb;
end;
$$;
revoke all on function public.send_message(uuid, uuid, uuid, text) from public;
grant execute on function public.send_message(uuid, uuid, uuid, text) to authenticated;

create or replace function public.get_messages(p_other_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Not logged in';
  end if;

  select coalesce(jsonb_agg(row_to_json(m)), '[]'::jsonb) into v_result
  from (
    select * from public.messages
    where (sender_id = v_user_id and receiver_id = p_other_user_id)
       or (sender_id = p_other_user_id and receiver_id = v_user_id)
    order by created_at asc
  ) m;

  return v_result;
end;
$$;
revoke all on function public.get_messages(uuid) from public;
grant execute on function public.get_messages(uuid) to authenticated;

create or replace function public.get_recent_messages()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Not logged in';
  end if;

  select coalesce(jsonb_agg(row_to_json(m)), '[]'::jsonb) into v_result
  from (
    select * from public.messages
    where sender_id = v_user_id or receiver_id = v_user_id
    order by created_at desc
  ) m;

  return v_result;
end;
$$;
revoke all on function public.get_recent_messages() from public;
grant execute on function public.get_recent_messages() to authenticated;

alter table public.messages replica identity full;
alter publication supabase_realtime add table public.messages;

-- Atomic checkout: locks every product row, validates stock, checks coupons with FOR UPDATE,
-- inserts the order, snapshots product details, records coupon redemption, and decreases inventory.
drop function if exists public.place_order(jsonb, jsonb, text);
drop function if exists public.place_order(jsonb, jsonb, text, text);
create or replace function public.place_order(
  p_customer jsonb,
  p_items jsonb,
  p_payment_method text default 'cash_on_delivery',
  p_coupon_code text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_order_id uuid;
  v_item jsonb;
  v_product public.product%rowtype;
  v_product_id uuid;
  v_requested_quantity integer;
  v_unit_price numeric(12,2);
  v_subtotal numeric(12,2) := 0;
  v_final_total numeric(12,2) := 0;
  v_clean_code text := upper(trim(coalesce(p_coupon_code, '')));
  v_coupon public.coupons%rowtype;
  v_discount numeric(12,2) := 0;
begin
  if v_user_id is null then
    raise exception 'You must be logged in to place an order';
  end if;
  if p_payment_method not in ('cash_on_delivery', 'razorpay') then
    raise exception 'Unsupported payment method';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'Your cart is empty';
  end if;
  if p_customer is null or jsonb_typeof(p_customer) <> 'object' then
    raise exception 'Delivery details are required';
  end if;

  insert into public.orders (
    user_id, customer_name, customer_email, customer_phone,
    address, country, state, city, total_price, payment_method, status
  ) values (
    v_user_id,
    p_customer->>'name',
    p_customer->>'email',
    p_customer->>'phone',
    p_customer->>'address',
    p_customer->>'country',
    p_customer->>'state',
    p_customer->>'city',
    0,
    p_payment_method,
    'pending'
  ) returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_requested_quantity := (v_item->>'quantity')::integer;
    if v_requested_quantity is null or v_requested_quantity <= 0 then
      raise exception 'Invalid product quantity';
    end if;

    select * into v_product
    from public.product
    where id = v_product_id
    for update;

    if not found then
      raise exception 'Product no longer exists';
    end if;
    if v_product.quantity < v_requested_quantity then
      raise exception 'OUT_OF_STOCK: %', v_product.name;
    end if;

    v_unit_price := coalesce(v_product.discount_price, v_product.price);
    insert into public.order_items (
      order_id, product_id, seller_id, product_name, product_image,
      unit_price, quantity, item_total
    ) values (
      v_order_id, v_product.id, v_product.user_id, v_product.name,
      v_product.img_url, v_unit_price, v_requested_quantity,
      v_unit_price * v_requested_quantity
    );

    v_subtotal := v_subtotal + (v_unit_price * v_requested_quantity);
    update public.product
    set quantity = quantity - v_requested_quantity,
        updated_at = now()
    where id = v_product.id;
  end loop;

  -- Atomic Server-Side Coupon Verification and Redemption
  if v_clean_code <> '' then
    select * into v_coupon
    from public.coupons
    where upper(code) = v_clean_code and is_active = true
    for update;

    if not found then
      raise exception 'Coupon "%" is invalid or inactive', v_clean_code;
    end if;
    if v_coupon.expires_at is not null and v_coupon.expires_at < now() then
      raise exception 'Coupon "%" has expired', v_clean_code;
    end if;
    if v_coupon.used_quantity >= v_coupon.total_quantity then
      raise exception 'Coupon "%" limit has been reached', v_clean_code;
    end if;
    if exists (
      select 1 from public.coupon_redemptions
      where coupon_id = v_coupon.id and user_id = v_user_id
    ) then
      raise exception 'You have already redeemed coupon "%"', v_clean_code;
    end if;
    if v_subtotal < v_coupon.min_order_amount then
      raise exception 'Minimum order amount of ₹% required for coupon "%"', v_coupon.min_order_amount, v_clean_code;
    end if;

    if v_coupon.discount_type = 'percentage' then
      v_discount := (v_subtotal * v_coupon.discount_value / 100);
      if v_coupon.max_discount is not null and v_discount > v_coupon.max_discount then
        v_discount := v_coupon.max_discount;
      end if;
    else
      v_discount := least(v_subtotal, v_coupon.discount_value);
    end if;

    -- Update coupon used quantity atomically
    update public.coupons
    set used_quantity = used_quantity + 1
    where id = v_coupon.id;

    -- Record single-use redemption
    insert into public.coupon_redemptions (coupon_id, user_id, order_id)
    values (v_coupon.id, v_user_id, v_order_id);
  end if;

  v_final_total := greatest(0, v_subtotal - v_discount);

  update public.orders set total_price = v_final_total, updated_at = now()
  where id = v_order_id;
  return v_order_id;
end;
$$;
revoke all on function public.place_order(jsonb, jsonb, text, text) from public;
grant execute on function public.place_order(jsonb, jsonb, text, text) to authenticated;

-- =========================================================
-- COUPON VALIDATION RPC
-- Validates a coupon code against minimum order, limits, and user redemption
-- =========================================================
create or replace function public.validate_coupon(
  p_code text,
  p_order_amount numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_clean_code text := upper(trim(coalesce(p_code, '')));
  v_coupon public.coupons%rowtype;
  v_discount numeric(12,2) := 0;
begin
  if v_clean_code = '' then
    return jsonb_build_object('valid', false, 'message', 'Please enter a coupon code');
  end if;

  select * into v_coupon
  from public.coupons
  where upper(code) = v_clean_code and is_active = true;

  if not found then
    return jsonb_build_object('valid', false, 'message', 'Coupon code is invalid or expired');
  end if;

  if v_coupon.expires_at is not null and v_coupon.expires_at < now() then
    return jsonb_build_object('valid', false, 'message', 'This coupon has expired');
  end if;

  if v_coupon.used_quantity >= v_coupon.total_quantity then
    return jsonb_build_object('valid', false, 'message', 'This coupon has reached its maximum redemption limit');
  end if;

  if v_user_id is not null and exists (
    select 1 from public.coupon_redemptions
    where coupon_id = v_coupon.id and user_id = v_user_id
  ) then
    return jsonb_build_object('valid', false, 'message', 'You have already redeemed this coupon');
  end if;

  if p_order_amount < v_coupon.min_order_amount then
    return jsonb_build_object(
      'valid', false,
      'message', format('Minimum order amount of ₹%s required for this coupon', v_coupon.min_order_amount)
    );
  end if;

  if v_coupon.discount_type = 'percentage' then
    v_discount := (p_order_amount * v_coupon.discount_value / 100);
    if v_coupon.max_discount is not null and v_discount > v_coupon.max_discount then
      v_discount := v_coupon.max_discount;
    end if;
  else
    v_discount := least(p_order_amount, v_coupon.discount_value);
  end if;

  return jsonb_build_object(
    'valid', true,
    'code', v_coupon.code,
    'title', v_coupon.title,
    'description', v_coupon.description,
    'discount', v_discount,
    'discount_type', v_coupon.discount_type,
    'discount_value', v_coupon.discount_value,
    'message', format('Coupon applied successfully! You saved ₹%s', v_discount)
  );
end;
$$;
revoke all on function public.validate_coupon(text, numeric) from public;
grant execute on function public.validate_coupon(text, numeric) to authenticated, anon;

create or replace function public.recommended_products(target_product_id uuid)
returns setof public.product
language sql
security definer
set search_path = public
as $$
  select p.*
  from public.product p
  join public.order_items related_item on related_item.product_id = p.id
  join public.order_items purchased_item
    on purchased_item.order_id = related_item.order_id
  where purchased_item.product_id = target_product_id
    and p.id <> target_product_id
  group by p.id
  order by count(distinct related_item.order_id) desc, p.created_at desc
  limit 8;
$$;
revoke all on function public.recommended_products(uuid) from public;
grant execute on function public.recommended_products(uuid) to authenticated;

create or replace function public.popular_products()
returns setof public.product
language sql
security definer
set search_path = public
as $$
  select p.*
  from public.product p
  join public.order_items oi on oi.product_id = p.id
  group by p.id
  order by sum(oi.quantity) desc, p.created_at desc
  limit 8;
$$;
revoke all on function public.popular_products() from public;
grant execute on function public.popular_products() to authenticated;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'You must be logged in to delete your account';
  end if;

  delete from public.order_items
  where seller_id = v_user_id
     or product_id in (
       select id from public.product where user_id = v_user_id
     );

  delete from public.product where user_id = v_user_id;
  delete from auth.users where id = v_user_id;
end;
$$;
revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;

-- Product image storage for seller uploads. The bucket is public because the
-- app stores public image URLs in product.img_url and displays them directly.
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

drop policy if exists "Public can view product images" on storage.objects;
drop policy if exists "Authenticated users can view product images" on storage.objects;
drop policy if exists "Authenticated users can view product image metadata" on storage.objects;
create policy "Authenticated users can view product image metadata"
on storage.objects for select
to authenticated
using (
  bucket_id = 'product-images'
  and exists (
    select 1
    from public.users
    where public.users.id = auth.uid()
      and public.users.role in ('Buyer', 'Seller')
  )
);

drop policy if exists "Authenticated users can upload product images" on storage.objects;
drop policy if exists "Sellers can upload product images" on storage.objects;
create policy "Sellers can upload product images"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and exists (
    select 1
    from public.users
    where public.users.id = auth.uid()
      and public.users.role = 'Seller'
  )
);

-- =========================================================
-- PHASE 4: STRICT ORDER STATUS STATE MACHINE TRIGGER
-- Enforces: pending -> paid -> packed -> shipped -> out for delivery -> delivered
-- Cancellations permitted before terminal states.
-- Terminal states 'delivered' and 'cancelled' are immutable.
-- =========================================================
create or replace function public.enforce_order_status_transition()
returns trigger
language plpgsql
security definer
as $$
begin
  -- No-op if status hasn't changed
  if old.status = new.status then
    return new;
  end if;

  -- Terminal state immutability
  if old.status in ('delivered', 'cancelled') then
    raise exception 'Order is in terminal state "%" and cannot be transitioned to "%"', old.status, new.status;
  end if;

  -- Enforce valid transition paths
  if old.status = 'pending' and new.status not in ('paid', 'packed', 'cancelled') then
    raise exception 'Invalid status transition from "%" to "%". Pending orders can only transition to "paid", "packed", or "cancelled"', old.status, new.status;
  elsif old.status = 'paid' and new.status not in ('packed', 'cancelled') then
    raise exception 'Invalid status transition from "%" to "%". Paid orders can only transition to "packed" or "cancelled"', old.status, new.status;
  elsif old.status = 'packed' and new.status not in ('shipped', 'cancelled') then
    raise exception 'Invalid status transition from "%" to "%". Packed orders can only transition to "shipped" or "cancelled"', old.status, new.status;
  elsif old.status = 'shipped' and new.status not in ('out for delivery', 'delivered', 'cancelled') then
    raise exception 'Invalid status transition from "%" to "%". Shipped orders can only transition to "out for delivery", "delivered", or "cancelled"', old.status, new.status;
  elsif old.status = 'out for delivery' and new.status not in ('delivered', 'cancelled') then
    raise exception 'Invalid status transition from "%" to "%". Out for delivery orders can only transition to "delivered" or "cancelled"', old.status, new.status;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_order_status_transition on public.orders;
create trigger trg_order_status_transition
before update of status on public.orders
for each row execute procedure public.enforce_order_status_transition();

-- =========================================================
-- PHASE 4: COUPON VALIDATION RPC
-- Validates code, expiration, stock/quota, minimum order & per-user redemption
-- =========================================================
create or replace function public.validate_coupon(
  p_code text,
  p_order_amount numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_coupon public.coupons%rowtype;
  v_clean_code text := upper(trim(coalesce(p_code, '')));
  v_discount numeric(12,2) := 0;
begin
  if v_user_id is null then
    return jsonb_build_object('valid', false, 'message', 'Please log in to apply a coupon');
  end if;

  if v_clean_code = '' then
    return jsonb_build_object('valid', false, 'message', 'Coupon code cannot be empty');
  end if;

  select * into v_coupon
  from public.coupons
  where upper(code) = v_clean_code and is_active = true;

  if not found then
    return jsonb_build_object('valid', false, 'message', 'Invalid or inactive coupon code');
  end if;

  if v_coupon.expires_at is not null and v_coupon.expires_at < now() then
    return jsonb_build_object('valid', false, 'message', 'This coupon has expired');
  end if;

  if v_coupon.used_quantity >= v_coupon.total_quantity then
    return jsonb_build_object('valid', false, 'message', 'This coupon has reached its maximum redemption limit');
  end if;

  if exists (
    select 1 from public.coupon_redemptions
    where coupon_id = v_coupon.id and user_id = v_user_id
  ) then
    return jsonb_build_object('valid', false, 'message', 'You have already redeemed this coupon');
  end if;

  if p_order_amount < v_coupon.min_order_amount then
    return jsonb_build_object(
      'valid', false,
      'message', format('Minimum order of ₹%s required for this coupon', v_coupon.min_order_amount)
    );
  end if;

  if v_coupon.discount_type = 'percentage' then
    v_discount := (p_order_amount * v_coupon.discount_value / 100);
    if v_coupon.max_discount is not null and v_discount > v_coupon.max_discount then
      v_discount := v_coupon.max_discount;
    end if;
  else
    v_discount := least(p_order_amount, v_coupon.discount_value);
  end if;

  return jsonb_build_object(
    'valid', true,
    'code', v_coupon.code,
    'title', v_coupon.title,
    'discount_type', v_coupon.discount_type,
    'discount_value', v_coupon.discount_value,
    'discount_amount', v_discount,
    'message', format('Coupon applied! You save ₹%s', v_discount)
  );
end;
$$;
revoke all on function public.validate_coupon(text, numeric) from public;
grant execute on function public.validate_coupon(text, numeric) to authenticated;

-- =========================================================
-- PHASE 4: VERIFY AND CONFIRM PAYMENT RPC
-- Called only by trusted Edge Functions after Razorpay signature/capture checks.
-- =========================================================
create or replace function public.attach_razorpay_order(
  p_order_id uuid,
  p_razorpay_order_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  if auth.uid() is null then
    raise exception 'You must be logged in to start payment';
  end if;
  if p_razorpay_order_id is null or trim(p_razorpay_order_id) = '' then
    raise exception 'Razorpay order ID is required';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id and user_id = auth.uid()
  for update;
  if not found then
    raise exception 'Order not found';
  end if;
  if v_order.payment_method <> 'razorpay'
     or v_order.payment_status <> 'pending'
     or v_order.status <> 'pending' then
    raise exception 'Order is not awaiting Razorpay payment';
  end if;
  if v_order.razorpay_order_id is not null
     and v_order.razorpay_order_id <> p_razorpay_order_id then
    raise exception 'A different Razorpay order is already linked';
  end if;

  update public.orders
  set razorpay_order_id = p_razorpay_order_id,
      updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'order_id', p_order_id,
    'razorpay_order_id', p_razorpay_order_id
  );
end;
$$;
revoke all on function public.attach_razorpay_order(uuid, text) from public;
grant execute on function public.attach_razorpay_order(uuid, text) to authenticated;

create or replace function public.cancel_razorpay_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_item record;
  v_rows_updated integer;
begin
  if auth.uid() is null then
    raise exception 'You must be logged in to cancel payment';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id and user_id = auth.uid()
  for update;
  if not found then
    raise exception 'Order not found';
  end if;
  if v_order.payment_method <> 'razorpay'
     or v_order.status <> 'pending'
     or v_order.payment_status <> 'pending'
     or v_order.razorpay_order_id is not null then
    raise exception 'Order cannot be safely cancelled';
  end if;

  for v_item in
    select product_id, sum(quantity)::integer as quantity
    from public.order_items
    where order_id = p_order_id
    group by product_id
    order by product_id
  loop
    update public.product
    set quantity = quantity + v_item.quantity,
        updated_at = now()
    where id = v_item.product_id;
    get diagnostics v_rows_updated = row_count;
    if v_rows_updated <> 1 then
      raise exception 'Could not restore inventory for cancelled payment';
    end if;
  end loop;

  -- Restore coupon if one was applied
  update public.coupons
  set used_quantity = greatest(0, used_quantity - 1)
  where id in (
    select coupon_id from public.coupon_redemptions
    where order_id = p_order_id and user_id = auth.uid()
  );
  delete from public.coupon_redemptions
  where order_id = p_order_id and user_id = auth.uid();

  update public.orders
  set status = 'cancelled',
      payment_status = 'failed',
      updated_at = now()
  where id = p_order_id;

  return jsonb_build_object('success', true, 'status', 'cancelled');
end;
$$;
revoke all on function public.cancel_razorpay_order(uuid) from public;
grant execute on function public.cancel_razorpay_order(uuid) to authenticated;

drop function if exists public.verify_and_confirm_payment(uuid, text, text, text);
create or replace function public.verify_and_confirm_payment(
  p_event_id text,
  p_order_id uuid,
  p_razorpay_order_id text,
  p_razorpay_payment_id text,
  p_amount integer,
  p_currency text,
  p_event_type text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_existing_event public.payment_webhook_events%rowtype;
begin
  if p_event_id is null or trim(p_event_id) = ''
     or p_razorpay_order_id is null or trim(p_razorpay_order_id) = ''
     or p_razorpay_payment_id is null or trim(p_razorpay_payment_id) = ''
     or p_event_type is null or trim(p_event_type) = ''
     or p_amount is null or p_currency is null or p_currency <> 'INR' then
    raise exception 'Invalid Razorpay payment details';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'Order not found';
  end if;
  if v_order.payment_method <> 'razorpay'
     or v_order.razorpay_order_id <> p_razorpay_order_id
     or round(v_order.total_price * 100)::integer <> p_amount then
    raise exception 'Razorpay payment does not match this order';
  end if;

  select * into v_existing_event
  from public.payment_webhook_events
  where event_id = p_event_id;
  if found then
    if v_existing_event.order_id <> p_order_id
       or v_existing_event.event_type <> p_event_type then
      raise exception 'Razorpay event ID was already used for a different event';
    end if;
    return jsonb_build_object(
      'success', true,
      'status', 'paid',
      'already_processed', true
    );
  end if;

  if v_order.payment_status = 'paid' then
    if v_order.razorpay_payment_id = p_razorpay_payment_id then
      return jsonb_build_object(
        'success', true,
        'status', 'paid',
        'already_processed', true
      );
    end if;
    raise exception 'A different payment has already been applied to this order';
  end if;
  if v_order.status <> 'pending' or v_order.payment_status <> 'pending' then
    raise exception 'Order is no longer awaiting payment';
  end if;

  insert into public.payment_webhook_events (
    event_id, order_id, event_type, payload, status
  ) values (
    p_event_id, p_order_id, p_event_type, coalesce(p_payload, '{}'::jsonb), 'processed'
  );

  update public.orders
  set status = 'paid',
      payment_status = 'paid',
      razorpay_payment_id = p_razorpay_payment_id,
      updated_at = now()
  where id = p_order_id;

  return jsonb_build_object('success', true, 'status', 'paid');
end;
$$;
revoke all on function public.verify_and_confirm_payment(
  text, uuid, text, text, integer, text, text, jsonb
) from public, anon, authenticated;
grant execute on function public.verify_and_confirm_payment(
  text, uuid, text, text, integer, text, text, jsonb
) to service_role;

-- =========================================================
-- PHASE 4: FCM TOKEN REGISTRATION RPC
-- Saves or refreshes device push tokens for authenticated users
-- =========================================================
create or replace function public.register_fcm_token(
  p_token text,
  p_device_info text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null or p_token is null or trim(p_token) = '' then
    return;
  end if;

  insert into public.user_fcm_tokens (user_id, token, device_info, updated_at)
  values (v_user_id, trim(p_token), p_device_info, now())
  on conflict (token) do update
  set user_id = v_user_id,
      device_info = excluded.device_info,
      updated_at = now();
end;
$$;
revoke all on function public.register_fcm_token(text, text) from public;
grant execute on function public.register_fcm_token(text, text) to authenticated;

-- =========================================================
-- PHASE 4: AUTOMATIC REAL-TIME NOTIFICATIONS TRIGGER
-- 1. Notifies merchants when new order is placed
-- 2. Notifies buyer when order status changes
-- =========================================================
create or replace function public.trigger_order_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller_id uuid;
begin
  if tg_op = 'INSERT' then
    -- When a new order is inserted, notify each distinct seller involved in the order
    for v_seller_id in
      select distinct seller_id from public.order_items where order_id = new.id
    loop
      insert into public.notifications (user_id, order_id, title, message)
      values (
        v_seller_id,
        new.id,
        'New Order Received!',
        format('Customer %s placed an order for ₹%s (Payment: %s).', new.customer_name, new.total_price, new.payment_method)
      );

      insert into public.push_notification_logs (user_id, order_id, title, body, data)
      values (
        v_seller_id,
        new.id,
        'New Order Received!',
        format('You have a new order (#%s) for ₹%s.', substr(new.id::text, 1, 8), new.total_price),
        jsonb_build_object('order_id', new.id, 'type', 'new_order')
      );
    end loop;

  elsif tg_op = 'UPDATE' and old.status is distinct from new.status then
    -- When status changes, notify buyer
    insert into public.notifications (user_id, order_id, title, message)
    values (
      new.user_id,
      new.id,
      format('Order Status: %s', initcap(new.status)),
      format('Your order status has been updated to "%s".', new.status)
    );

    insert into public.push_notification_logs (user_id, order_id, title, body, data)
    values (
      new.user_id,
      new.id,
      format('Order Status: %s', initcap(new.status)),
      format('Your order is now %s.', new.status),
      jsonb_build_object('order_id', new.id, 'type', 'order_status', 'status', new.status)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_order_notifications on public.orders;
create trigger trg_order_notifications
after insert or update on public.orders
for each row execute procedure public.trigger_order_notifications();

-- =========================================================
-- TRIGGER: Real-Time Notifications for Return Requests
-- =========================================================
create or replace function public.trigger_return_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    -- When a buyer requests a return, notify the seller
    insert into public.notifications (user_id, order_id, title, message)
    values (
      new.seller_id,
      new.order_id,
      'New Return Requested',
      'A buyer has requested a return for one of your order items.'
    );

    insert into public.push_notification_logs (user_id, order_id, title, body, data)
    values (
      new.seller_id,
      new.order_id,
      'New Return Requested',
      'A buyer has requested a return for one of your order items.',
      jsonb_build_object('order_id', new.order_id, 'type', 'return_request', 'return_id', new.id)
    );

  elsif tg_op = 'UPDATE' and old.status is distinct from new.status then
    -- When seller approves/rejects the return, notify the buyer
    insert into public.notifications (user_id, order_id, title, message)
    values (
      new.buyer_id,
      new.order_id,
      format('Return Status: %s', initcap(new.status)),
      format('Your return request has been marked as %s.', new.status)
    );

    insert into public.push_notification_logs (user_id, order_id, title, body, data)
    values (
      new.buyer_id,
      new.order_id,
      format('Return Status: %s', initcap(new.status)),
      format('Your return request is now %s.', new.status),
      jsonb_build_object('order_id', new.order_id, 'type', 'return_status', 'status', new.status, 'return_id', new.id)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_return_notifications on public.return_requests;
create trigger trg_return_notifications
after insert or update on public.return_requests
for each row execute procedure public.trigger_return_notifications();

-- Enable Supabase Realtime for instant in-app notification streaming
alter table public.notifications replica identity full;
alter publication supabase_realtime add table public.notifications;

-- =========================================================
-- SEED INITIAL ACTIVE COUPONS
-- =========================================================
insert into public.coupons (
  code, title, description, discount_type, discount_value, min_order_amount, max_discount, total_quantity, used_quantity, is_active
) values
  ('WELCOME50', '50% Welcome Discount', 'Get 50% discount up to ₹200 on your purchase', 'percentage', 50, 300, 200, 100, 0, true),
  ('FLAT100', 'Flat ₹100 Off', 'Save flat ₹100 on orders above ₹500', 'fixed', 100, 500, null, 50, 0, true),
  ('SAVE10', '10% Saver Offer', '10% discount on all items above ₹200', 'percentage', 10, 200, 150, 200, 0, true)
on conflict (code) do update set
  title = excluded.title,
  description = excluded.description,
  discount_type = excluded.discount_type,
  discount_value = excluded.discount_value,
  min_order_amount = excluded.min_order_amount,
  max_discount = excluded.max_discount,
  total_quantity = excluded.total_quantity,
  is_active = excluded.is_active;

-- =========================================================
-- RAZORPAY PAYMENT LEDGER AND UPI QR CONFIRMATION
-- =========================================================
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  razorpay_order_id text unique,
  razorpay_payment_id text unique,
  razorpay_signature text,
  qr_code_id text unique,
  qr_image_url text,
  amount numeric(12, 2) not null check (amount > 0),
  currency text not null default 'INR' check (char_length(currency) = 3),
  status text not null default 'created'
    check (status in ('created', 'paid', 'failed')),
  payment_method text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payments_provider_reference_check
    check (razorpay_order_id is not null or qr_code_id is not null)
);

create index if not exists payments_user_created_idx
  on public.payments(user_id, created_at desc);

alter table public.payments enable row level security;
revoke all on public.payments from public, anon, authenticated;
grant select on public.payments to authenticated;
grant all on public.payments to service_role;

drop policy if exists "Users can read own payments" on public.payments;
create policy "Users can read own payments"
  on public.payments for select to authenticated
  using (auth.uid() = user_id);

create or replace function public.set_payment_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at
before update on public.payments
for each row execute function public.set_payment_updated_at();

create or replace function public.sync_payment_from_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.payments
  set status = case
        when new.payment_status = 'paid' then 'paid'
        when new.payment_status in ('failed', 'refunded') or new.status = 'cancelled'
          then 'failed'
        else status
      end,
      razorpay_payment_id = coalesce(new.razorpay_payment_id, razorpay_payment_id)
  where order_id = new.id;
  return new;
end;
$$;

revoke all on function public.sync_payment_from_order() from public, anon, authenticated;
drop trigger if exists orders_sync_payment on public.orders;
create trigger orders_sync_payment
after update of payment_status, razorpay_payment_id, status on public.orders
for each row execute function public.sync_payment_from_order();

create or replace function public.confirm_qr_payment(
  p_event_id text,
  p_order_id uuid,
  p_qr_code_id text,
  p_payment_id text,
  p_amount integer,
  p_currency text,
  p_payment_method text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_payment public.payments%rowtype;
  v_existing_event public.payment_webhook_events%rowtype;
begin
  if p_event_id is null or trim(p_event_id) = ''
     or p_qr_code_id is null or trim(p_qr_code_id) = ''
     or p_payment_id is null or trim(p_payment_id) = ''
     or p_amount is null or p_amount <= 0
     or p_currency is distinct from 'INR'
     or p_payment_method is null or trim(p_payment_method) = '' then
    raise exception 'Invalid Razorpay QR payment details';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id
  for update;
  if not found then
    raise exception 'Order not found';
  end if;

  select * into v_payment
  from public.payments
  where order_id = p_order_id and qr_code_id = p_qr_code_id
  for update;
  if not found or v_order.payment_method <> 'razorpay'
     or v_payment.currency <> p_currency
     or round(v_payment.amount * 100)::integer <> p_amount
     or round(v_order.total_price * 100)::integer <> p_amount then
    raise exception 'QR payment does not match this order';
  end if;

  select * into v_existing_event
  from public.payment_webhook_events
  where event_id = p_event_id;
  if found then
    if v_existing_event.order_id <> p_order_id
       or v_existing_event.event_type <> 'qr_code.credited' then
      raise exception 'Razorpay event ID was already used for a different event';
    end if;
    return jsonb_build_object('success', true, 'status', 'paid', 'already_processed', true);
  end if;

  if v_order.payment_status = 'paid' then
    if v_order.razorpay_payment_id = p_payment_id then
      return jsonb_build_object('success', true, 'status', 'paid', 'already_processed', true);
    end if;
    raise exception 'A different payment has already been applied to this order';
  end if;
  if v_order.status <> 'pending' or v_order.payment_status <> 'pending'
     or v_payment.status <> 'created' then
    raise exception 'Order is no longer awaiting QR payment';
  end if;

  insert into public.payment_webhook_events (
    event_id, order_id, event_type, payload, status
  ) values (
    p_event_id, p_order_id, 'qr_code.credited', coalesce(p_payload, '{}'::jsonb), 'processed'
  );

  update public.orders
  set status = 'paid',
      payment_status = 'paid',
      razorpay_payment_id = p_payment_id,
      updated_at = now()
  where id = p_order_id;

  update public.payments
  set payment_method = p_payment_method,
      razorpay_payment_id = p_payment_id
  where id = v_payment.id;

  return jsonb_build_object('success', true, 'status', 'paid');
end;
$$;

revoke all on function public.confirm_qr_payment(
  text, uuid, text, text, integer, text, text, jsonb
) from public, anon, authenticated;
grant execute on function public.confirm_qr_payment(
  text, uuid, text, text, integer, text, text, jsonb
) to service_role;
