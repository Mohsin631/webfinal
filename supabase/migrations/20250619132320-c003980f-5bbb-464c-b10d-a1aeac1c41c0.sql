
-- Drop the existing policy that's causing the conflict
DROP POLICY IF EXISTS "Users can view own roles" ON public.user_roles;

-- Create a security definer function to check user roles safely
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS user_role AS $$
BEGIN
  RETURN (
    SELECT role 
    FROM public.user_roles 
    WHERE user_roles.user_id = $1 
    LIMIT 1
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Drop existing problematic policies
DROP POLICY IF EXISTS "Only admins can insert products" ON public.products;
DROP POLICY IF EXISTS "Only admins can update products" ON public.products;
DROP POLICY IF EXISTS "Only admins can delete products" ON public.products;
DROP POLICY IF EXISTS "Admins can view all orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can update orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can view all order items" ON public.order_items;
DROP POLICY IF EXISTS "Admins can view all roles" ON public.user_roles;

-- Recreate policies using the security definer function
CREATE POLICY "Only admins can insert products" 
  ON public.products FOR INSERT 
  WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Only admins can update products" 
  ON public.products FOR UPDATE 
  USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Only admins can delete products" 
  ON public.products FOR DELETE 
  USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admins can view all orders" 
  ON public.orders FOR SELECT 
  USING (public.get_user_role(auth.uid()) = 'admin' OR auth.uid() = user_id);

CREATE POLICY "Admins can update orders" 
  ON public.orders FOR UPDATE 
  USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admins can view all order items" 
  ON public.order_items FOR SELECT 
  USING (
    public.get_user_role(auth.uid()) = 'admin' 
    OR EXISTS (
      SELECT 1 FROM public.orders 
      WHERE id = order_id AND user_id = auth.uid()
    )
  );

-- Recreate the user_roles policies without recursion
CREATE POLICY "Users can view own roles" 
  ON public.user_roles FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all roles" 
  ON public.user_roles FOR SELECT 
  USING (public.get_user_role(auth.uid()) = 'admin');
