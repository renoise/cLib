--[[===============================================================================================
-- cPersistence
===============================================================================================]]--

--[[--

Add the ability to store a class as serialized data 
.

# How to use

cPersistence makes it simple to add basic persistence to a class. 

TODO: Provide an example 


Note: this class is meant to replace the (now deprecated) `cDocument` class

--]]

--=================================================================================================

require (_clibroot.."cTable")
require (_clibroot.."cReflection")


class 'cPersistence'

---------------------------------------------------------------------------------------------------
-- constructor

function cPersistence:__init()

end

---------------------------------------------------------------------------------------------------
-- load serialized string from disk
-- @return boolean, true when loading succeeded
-- @return string, when an error occurred

function cPersistence:load(file_path)
  TRACE("cPersistence:load(file_path)")
  
  -- confirm that file is valid
  local str_def,err = cFilesystem.load_string(file_path)
  --print(">>> load_definition - load_string - str_def,err",str_def,err)
  local passed = self:looks_like_definition(str_def)
  if not passed then
    return false,("The file '%s' does not look like a definition"):format(file_path)
  end
  
  -- load the definition
  local passed,err = pcall(function()
    assert(loadfile(file_path))
  end) 
  if not passed then
    err = "*** Error: Failed to load the definition '"..file_path.."' - "..err
    return false,err
  end
  
  local def = assert(loadfile(file_path))()
  self:assign_definition(def)
  
end

---------------------------------------------------------------------------------------------------
-- save serialized string to disk 
-- @return boolean, true when loading succeeded
-- @return string, when an error occurred

function cPersistence:save(file_path)
  TRACE("cPersistence:save(file_path)",file_path)

  local got_saved,err = cFilesystem.write_string_to_file(file_path,self:serialize())
  if not got_saved then
    return false,err
  end

  return true

end

---------------------------------------------------------------------------------------------------
-- @return string 

function cPersistence:serialize()
  TRACE("cPersistence:serialize()")

  return cLib.serialize_table(self:obtain_definition())

end

---------------------------------------------------------------------------------------------------
-- assign definition to class 
-- @param t (table)

function cPersistence:assign_definition(def)
  TRACE("cPersistence:assign_definition(def)",def)

  for _,prop_name in ipairs(self.__PERSISTENCE) do 
    local prop_def = def[prop_name]
    if prop_def.__type and prop_def.__version then 
      --print(">>> looks like a persisted object",prop_name,prop_def.__type)
      -- check if the type is available in the global scope 
      if not rawget(_G,prop_def.__type) then 
        renoise.app():show_warning(        
          ("Could not instantiate: unknown class '%s'"):format(prop_def.__type))
      else
        self[prop_name] = _G[prop_def.__type]()
        self[prop_name]:assign_definition(prop_def)
      end
    else
      --print(">>> plain assignment",prop_name,prop_def)
      self[prop_name] = prop_def
    end
  end

end  

---------------------------------------------------------------------------------------------------
-- look for certain "things" to confirm that this is a valid definition
-- @param str_def (string)
-- @return bool

function cPersistence:looks_like_definition(str_def)
  TRACE("cPersistence:looks_like_definition(str_def)",str_def)

  local pre = '\[?\"?'
  local post = '\]?\"?[%s]*=[%s]*{'

  for _,prop_name in ipairs(self.__PERSISTENCE) do 
    if not string.find(str_def,pre..prop_name..post) then
      return false
    end
  end
  return true

end

---------------------------------------------------------------------------------------------------
-- obtain a (serializable) table representation of the class
-- note: override this method to define your own implementation 
-- @return table 

function cPersistence:obtain_definition()
  TRACE("cPersistence:obtain_definition()")

  -- core properties (always present)
  local def = {
    __type = type(self),
    __version = self.__VERSION or 0
  }

  for _,prop_name in ipairs(self.__PERSISTENCE) do 
    local prop_def = cPersistence.obtain_property_definition(self[prop_name],prop_name)
    if prop_def then 
      def[prop_name] = prop_def
    end
  end
  return def

end

---------------------------------------------------------------------------------------------------

function cPersistence.obtain_property_definition(prop,prop_name)
  TRACE("cPersistence.obtain_property_definition(prop,prop_name)",prop,prop_name)

  local def = {}
  if cReflection.is_serializable_type(prop) then
    if (type(prop)=="table") then 
      -- distinguish between indexed and associative tables 
      if cTable.is_indexed(prop) then 
        -- make sure to take a recursive copy
        --def[prop_name] = table.rcopy(prop)
        --def = table.rcopy(prop)

        for k,v in ipairs(prop) do
          local table_prop_def = cPersistence.obtain_property_definition(v,k)
          if table_prop_def then 
            def[k] = table_prop_def
          end          
        end   

      else
        -- associative array ("object")
        for k,v in pairs(prop) do
          local table_prop_def = cPersistence.obtain_property_definition(v,k)
          if table_prop_def then 
            def[k] = table_prop_def
          end          
        end        
      end
    else
      -- primitive value (bool, string, number)
      def = prop
    end
  else 
    -- check if instance of cPersistence
    if prop.__PERSISTENCE and prop.obtain_definition then 
      def = prop:obtain_definition()
    else 
      LOG("Warning: this property is not serializable:",prop_name)
    end
  end
  return def

end

