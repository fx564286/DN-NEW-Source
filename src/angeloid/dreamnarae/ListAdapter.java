package angeloid.dreamnarae;

import java.util.ArrayList;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.TextView;

public class ListAdapter extends ArrayAdapter<DNMenu> {
 
    private ArrayList<DNMenu> items;
 
    public ListAdapter(Context context, int textViewResourceId,
            ArrayList<DNMenu> items) {
        super(context, textViewResourceId, items);
        this.items = items; }
 
    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View v = convertView;
        if (v == null) {
             
            LayoutInflater vi = (LayoutInflater) getContext().getSystemService(
                    Context.LAYOUT_INFLATER_SERVICE);
            v = vi.inflate(R.layout.dnmenulayout, null);
        }
        DNMenu custom_list_data = items.get(position);
 
        if (custom_list_data != null) {
            //하나의 이미지뷰와 2개의 텍스트뷰 정보를 받아온다.
            ImageView iv = (ImageView)v.findViewById(R.id.icon);
            TextView tv_Main = (TextView) v.findViewById(R.id.title);
            TextView tv_Sub = (TextView) v.findViewById(R.id.subtitle);
             
            // 현재 item의 position에 맞는 이미지와 글을 넣어준다.          
            iv.setBackgroundResource(custom_list_data.getImage_ID());
            tv_Main.setText(custom_list_data.getMain_Title());
            tv_Sub.setText(custom_list_data.getSub_Title());
        }
 
        return v;
    }
}
 
class DNMenu {
    private int Image_ID;
    private String Main_Title;
    private String Sub_Title;
 
    public DNMenu(int _Image_ID, String _Main_Title, String _Sub_Title) {
        this.setImage_ID(_Image_ID);
        this.setMain_Title(_Main_Title);
        this.setSub_Title(_Sub_Title);
    }
 
    public int getImage_ID() {
        return Image_ID;
    }
 
    public void setImage_ID(int image_ID) {
        Image_ID = image_ID;
    }
 
    public String getMain_Title() {
        return Main_Title;
    }
 
    public void setMain_Title(String main_Title) {
        Main_Title = main_Title;
    }
 
    public String getSub_Title() {
        return Sub_Title;
    }
 
    public void setSub_Title(String sub_Title) {
        Sub_Title = sub_Title;
    }
     
}