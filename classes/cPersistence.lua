--[[===============================================================================================
-- cPersistence
===============================================================================================]]--

--[[--

Add the ability to store a class as serialized data 
.

# About cPersistence

* Use it to add persistence to your class 
* TODO: Define converters that allow upgrading classes 

Note: this class is meant to replace the (now obsolete) `cDocument` class

# How it works 

To make your class support persistence, make it extend this class:

  class 'MyClass' (cPersistence)

Next, make sure that class properties are picked up 
There are two fundamental approaches that can be used:
1. Let cPersistence figure out which properties to save 
2. In more advanced cases, specify a method called `obtain_definition` in your class 

* The method is called , and should return a table with primitive values


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
-- @return string 

function cPersistence:serialize()
  TRACE("cPersistence:serialize()")

  return cLib.serialize_table(self:obtain_definition())

end

---------------------------------------------------------------------------------------------------
-- obtain a (serializable) table representation of the class
-- note: override this method to define your own implementation 
-- @return table 

function cPersistence:obtain_definition()
  TRACE("cPersistence:obtain_definition()")

  local def = {}

  for _,prop_name in ipairs(self.__PERSISTENCE) do 
    print("obtain_definition - prop_name",prop_name)
    local prop_def = cPersistence.obtain_property_definition(self[prop_name],prop_name)
    if prop_def then 
      def[prop_name] = prop_def
    end
  end
  print("obtain_definition - def:",rprint(def))
  return def

end

---------------------------------------------------------------------------------------------------
-- assign values in table (e.g. when applying deserialized values)
-- @param t (table)

function cPersistence:assign_definition(t)
  TRACE("cPersistence:assign_definition(t)",t)

  self.points = t.points

end  

-------------------------------------------------------------------------------
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

function cPersistence.obtain_property_definition(prop,prop_name)
  TRACE("cPersistence.obtain_property_definition(prop,prop_name)",prop,prop_name)
  print("type(prop)",type(prop))

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

