import'react-native-url-polyfill/auto';
import AsyncStorage from'@react-native-async-storage/async-storage';
import{createClient}from'@supabase/supabase-js';

const url=(process.env.EXPO_PUBLIC_SUPABASE_URL||'').trim();
const key=(process.env.EXPO_PUBLIC_SUPABASE_KEY||process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY||'').trim();

export const SUPABASE_CONFIGURED=Boolean(url&&key);
export const supabase=SUPABASE_CONFIGURED?createClient(url,key,{
  auth:{storage:AsyncStorage,autoRefreshToken:true,persistSession:true,detectSessionInUrl:false},
}):null;
