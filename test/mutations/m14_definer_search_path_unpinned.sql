-- search_path pin removed from a SECURITY DEFINER function
alter function private.my_team() reset search_path;
